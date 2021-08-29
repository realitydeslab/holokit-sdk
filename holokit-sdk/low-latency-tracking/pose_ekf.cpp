#include "pose_ekf.h"
#include "calcQ.h"
#include "eigen_utils.h"
#include<fstream>

PoseEKF::PoseEKF()
{
    initialized_ = false;
    predictionMade_ = false;
}


void PoseEKF::initialize(const Eigen::Vector3d & p, const Eigen::Vector3d & v,
                         const Eigen::Quaterniond & q, const Eigen::Vector3d & b_w,
                         const Eigen::Vector3d & b_a, const double & L,
                         const Eigen::Quaterniond & q_wv, const Eigen::Matrix<double, N_STATE, N_STATE> & P,
                         const Eigen::Vector3d & w_m, const Eigen::Vector3d & a_m,
                         const Eigen::Vector3d & g, const Eigen::Quaterniond & q_ci,
                         const Eigen::Vector3d & p_ci,const double time_stamp)
{
    initialized_ = false;
    predictionMade_ = false;
    
    // init state buffer
    for (int i = 0; i < N_STATE_BUFFER; i++)
    {
        StateBuffer_[i].reset();
    }
    
    idx_state_ = 0;
    idx_P_ = 0;
    idx_time_ = 0;
    
    State & state = StateBuffer_[idx_state_];
    state.p_ = p;
    state.v_ = v;
    state.q_ = q;
    state.b_w_ = b_w;
    state.b_a_ = b_a;
    state.L_ = 1;
    state.q_wv_ = q_wv;
    state.q_ci_ = q_ci;
    state.p_ci_ = p_ci;
    state.w_m_ = w_m;
    state.q_int_ = state.q_wv_;
    state.a_m_ = a_m;
    state.time_ = time_stamp;
    g_ = g;
    
    std::cout << "EKF initialize data: -----------------------------------------------" << std::endl;
    std::cout << "p_: " << state.p_ << std::endl;
    std::cout << "v_: " << state.v_ << std::endl;
    std::cout << "q_: " << state.q_.w() << std::endl;
    std::cout << "b_w: " << state.b_w_ << std::endl;
    std::cout << "b_a_: " << state.b_a_ << std::endl;
    std::cout << "L_: " << state.L_ << std::endl;
    std::cout << "q_wv_: " << state.q_wv_.w() << std::endl;
    std::cout << "q_ci_: " << state.q_ci_.w() << std::endl;
    std::cout << "p_ci_: " << state.p_ci_ << std::endl;
    std::cout << "w_m_: " << state.w_m_ << std::endl;
    std::cout << "q_int_: " << state.q_int_.w() << std::endl;
    std::cout << "a_m_: " << state.a_m_ << std::endl;
    std::cout << "time_: " << state.time_ << std::endl;
    
    StateBuffer_[idx_P_].P_ <<
    0.016580786012789, 0.012199934386656, -0.001458808893504, 0.021111179657363, 0.007427567799788, 0.000037801439852, 0.001171469788518, -0.001169015812942, 0.000103349776558, -0.000003813309102, 0.000015542937454, -0.000004252270155, -0.000344432741256, -0.000188322508425, -0.000003798930056
    , 0.012906597122666, 0.050841902184280, -0.001973897835999, 0.017928487134657, 0.043154792703685, 0.000622902345606, 0.002031938336114, 0.000401913571459, -0.000231214341523, -0.000016591523613, 0.000011431341737, 0.000007932426867, 0.000311267088246, -0.000201092426841, 0.000004838759439
    , -0.001345477564898, -0.000886479514041, 0.014171550800995, -0.002720150074738, 0.005673098074032, 0.007935105430084, 0.000687618072508, 0.000684952051662, 0.000022000355078, -0.000008608300759, -0.000000799656033, 0.000001107610267, -0.000106383032603, -0.000356814673233, -0.000068763009837
    , 0.020963436713918, 0.016241565921214, -0.002606622877434, 0.043695944809847, 0.008282523689966, -0.001656117837207, 0.001638402584126, -0.002060006975745, -0.001362992588971, -0.000001331527123, 0.000032032914797, 0.000004134961242, 0.000341541553429, -0.000100600014193, 0.000025055557965
    , 0.009314922877817, 0.046059780658109, 0.003565024589881, 0.015262116382857, 0.065035219304194, -0.001635353752413, 0.002492076189539, 0.001255538625264, -0.000034886338628, -0.000029672138211, 0.000006695719137, 0.000006779584634, 0.000273857318856, 0.000241559075524, 0.000026819562998
    , -0.000029025742686, 0.000535037190485, 0.007958782884182, -0.001871298319530, -0.002083832757411, 0.012983170487598, 0.000132746916981, 0.000083483650298, 0.000020140288935, -0.000001280987614, 0.000000838029756, -0.000000023238638, -0.000309256650920, 0.000094250769772, -0.000143135502707
    , 0.001237915701080, 0.002441754382058, 0.000642141528976, 0.001714303831639, 0.003652445463202, 0.000133021899909, 0.000491964329936, 0.000029132708361, 0.000054571029310, -0.000003531797659, 0.000002108308557, -0.000000655503604, -0.000036221301269, -0.000080404390258, -0.000002011184920
    , -0.001129210933568, 0.000810737713225, 0.000687013243217, -0.002320565048774, 0.001923423915051, 0.000083505758388, 0.000045906211371, 0.000464144924949, -0.000074174151652, -0.000001593433385, -0.000002820148135, 0.000001999456261, 0.000068256370057, -0.000050158974131, -0.000000228078959
    , 0.000118011626188, -0.000151939328593, -0.000003895302246, -0.001370909458095, 0.000050912424428, 0.000014452281684, 0.000048567151385, -0.000077773340951, 0.000550829253488, -0.000001499983629, -0.000001785224358, -0.000005364537487, 0.000036601273545, 0.000003384325422, -0.000000535444414
    , -0.000005270401860, -0.000021814853820, -0.000010366987197, -0.000002004330853, -0.000038399333509, -0.000001674413901, -0.000004404646641, -0.000002139516677, -0.000001756665835, 0.000002030485308, -0.000000003944807, 0.000000005740984, 0.000000210906625, 0.000000302650227, 0.000000014520529
    , 0.000016356223202, 0.000012074093112, -0.000001861055809, 0.000034349032581, 0.000006058258467, 0.000000706161071, 0.000001988651054, -0.000003017460220, -0.000001874017262, -0.000000012182671, 0.000002030455681, -0.000000019800818, 0.000000488355222, 0.000001489016879, 0.000000028100385
    , -0.000003154072126, 0.000010432789869, 0.000002047297121, 0.000005626984656, 0.000009913025254, 0.000000398401049, -0.000000326490919, 0.000002058769308, -0.000005291111547, 0.000000001086789, 0.000000001772501, 0.000002006545689, 0.000000044716134, 0.000000414518295, -0.000000135444520
    , -0.000348907202366, 0.000314489658858, -0.000097981489533, 0.000332751125893, 0.000276947396796, -0.000311267592250, -0.000035302086269, 0.000070545012901, 0.000036626247889, 0.000000400828580, 0.000000087733422, 0.000000120709451, 0.001026573886639, 0.000013867120528, 0.000031828760993
    , -0.000190283000907, -0.000192352300127, -0.000359131551235, -0.000107453347870, 0.000258576553615, 0.000091496162086, -0.000081280254994, -0.000048304910474, 0.000002800928601, 0.000000908905402, 0.000001125333299, 0.000000471832044, 0.000019874619416, 0.001029579153516, 0.000011053406779
    , -0.000004368584055, 0.000003124910665, -0.000067807653083, 0.000024474336501, 0.000022105549875, -0.000144033820704, -0.000002164571960, -0.000000083713348, -0.000000674226005, 0.000000019237635, 0.000000025526504, -0.000000057252892, 0.000032366581999, 0.000010736184803, 0.000111095066893;
    
    qvw_inittimer_ = 1;
    qbuff_ = Eigen::Matrix<double, nBuff_, 4>::Constant(0);
    // increase state pointers
    idx_state_++;
    idx_P_++;
    
    initialized_ = true;
}


void PoseEKF::imuCallback(const Eigen::Vector3d &linear_acceleration, const Eigen::Vector3d &angular_velocity, const double time_stamp)
{
    
    if (!initialized_)
        return;
    
    StateBuffer_[idx_state_].time_ = time_stamp;
    
    static int seq = 0;
    
    // get inputs
    StateBuffer_[idx_state_].a_m_ << linear_acceleration;
    StateBuffer_[idx_state_].w_m_ << angular_velocity;
    
    static Eigen::Vector3d last_am = Eigen::Vector3d(0, 0, 0);
    if (StateBuffer_[idx_state_].a_m_.norm() > 50)
        StateBuffer_[idx_state_].a_m_ = last_am;
    else
        last_am = StateBuffer_[idx_state_].a_m_;
    
    if (!predictionMade_)
    {
        if (fabs(StateBuffer_[(unsigned char)(idx_state_)].time_ - StateBuffer_[(unsigned char)(idx_state_ - 1)].time_) > 5)
        {
            printf("large time-gap re-initializing to last state\n");
            StateBuffer_[(unsigned char)(idx_state_ - 1)].time_ = StateBuffer_[(idx_state_)].time_;
            return;
        }
    }
    
    propagateState(StateBuffer_[idx_state_].time_ - StateBuffer_[(unsigned char)(idx_state_ - 1)].time_);
    predictProcessCovariance(StateBuffer_[idx_P_].time_ - StateBuffer_[(unsigned char)(idx_P_ - 1)].time_);
    
    checkForNumeric((double*)(&StateBuffer_[idx_state_ - 1].p_[0]), 3, "prediction p");
    
    predictionMade_ = true;
    
    seq++;
}


void PoseEKF::propagateState(const double dt)
{
    typedef const Eigen::Matrix<double, 4, 4> ConstMatrix4;
    typedef const Eigen::Vector3d ConstVector3;
    typedef Eigen::Matrix<double, 4, 4> Matrix4;
    
    // get references to current and previous state
    State & cur_state = StateBuffer_[idx_state_];
    State & prev_state = StateBuffer_[(unsigned char)(idx_state_ - 1)];
    
    // zero props:
    cur_state.b_w_ = prev_state.b_w_;
    cur_state.b_a_ = prev_state.b_a_;
    cur_state.p_ci_ = prev_state.p_ci_;
    cur_state.q_ci_ = prev_state.q_ci_;
    cur_state.L_ = prev_state.L_;
    cur_state.q_wv_ = prev_state.q_wv_;
    
    //  Eigen::Quaterniond dq;
    Eigen::Vector3d dv;
    ConstVector3 ew = cur_state.w_m_ - cur_state.b_w_;
    ConstVector3 ewold = prev_state.w_m_ - prev_state.b_w_;
    ConstVector3 ea = cur_state.a_m_ - cur_state.b_a_;
    ConstVector3 eaold = prev_state.a_m_ - prev_state.b_a_;
    ConstMatrix4 Omega = omegaMatJPL(ew);
    ConstMatrix4 OmegaOld = omegaMatJPL(ewold);
    Matrix4 OmegaMean = omegaMatJPL((ew + ewold) / 2);
    
    int div = 1;
    Matrix4 MatExp;
    MatExp.setIdentity();
    OmegaMean *= 0.5 * dt;
    for (int i = 1; i < 5; i++)
    {
        div *= i;
        MatExp = MatExp + OmegaMean / div;
        OmegaMean *= OmegaMean;
    }
    
    // first oder quat integration matrix
    ConstMatrix4 quat_int = MatExp + 1.0 / 48.0 * (Omega * OmegaOld - OmegaOld * Omega) * dt * dt;
    
    // first oder quaternion integration
    cur_state.q_.coeffs() = quat_int * prev_state.q_.coeffs();
    cur_state.q_.normalize();
    
    dv = (cur_state.q_.toRotationMatrix() * ea + prev_state.q_.toRotationMatrix() * eaold) / 2;
    cur_state.v_ = prev_state.v_ + (dv - g_) * dt;
    cur_state.p_ = prev_state.p_ + ((cur_state.v_ + prev_state.v_) / 2 * dt);
    
    idx_state_++;
}


void PoseEKF::predictProcessCovariance(const double dt)
{
    
    typedef const Eigen::Matrix3d ConstMatrix3;
    typedef const Eigen::Vector3d ConstVector3;
    typedef Eigen::Vector3d Vector3;
    
    // IMU noises
    ConstVector3 nav(ACC_NOISE_DENSITY, ACC_NOISE_DENSITY, ACC_NOISE_DENSITY) ;
    ConstVector3 nbav(ACC_RANDOM_WALK, ACC_RANDOM_WALK, ACC_RANDOM_WALK);
    
    ConstVector3 nwv(GYRO_NOISE_DENSITY, GYRO_NOISE_DENSITY, GYRO_NOISE_DENSITY);
    ConstVector3 nbwv(GYRO_RANDOM_WALK, GYRO_RANDOM_WALK, GYRO_RANDOM_WALK);
    
    ConstVector3 nqwvv = Eigen::Vector3d::Constant(0/*config_.noise_qwv*/);
    ConstVector3 nqciv = Eigen::Vector3d::Constant(0/*config_.noise_qci*/);
    ConstVector3 npicv = Eigen::Vector3d::Constant(0/*config_.noise_pic*/);
    
    // bias corrected IMU readings
    ConstVector3 ew = StateBuffer_[idx_P_].w_m_ - StateBuffer_[idx_P_].b_w_;
    ConstVector3 ea = StateBuffer_[idx_P_].a_m_ - StateBuffer_[idx_P_].b_a_;
    
    ConstMatrix3 a_sk = skew(ea);
    ConstMatrix3 w_sk = skew(ew);
    ConstMatrix3 eye3 = Eigen::Matrix3d::Identity();
    
    ConstMatrix3 C_eq = StateBuffer_[idx_P_].q_.toRotationMatrix();
    
    const double dt_p2_2 = dt * dt * 0.5; // dt^2 / 2
    const double dt_p3_6 = dt_p2_2 * dt / 3.0; // dt^3 / 6
    const double dt_p4_24 = dt_p3_6 * dt * 0.25; // dt^4 / 24
    const double dt_p5_120 = dt_p4_24 * dt * 0.2; // dt^5 / 120
    
    ConstMatrix3 Ca3 = C_eq * a_sk;
    ConstMatrix3 A = Ca3 * (-dt_p2_2 * eye3 + dt_p3_6 * w_sk - dt_p4_24 * w_sk * w_sk);
    ConstMatrix3 B = Ca3 * (dt_p3_6 * eye3 - dt_p4_24 * w_sk + dt_p5_120 * w_sk * w_sk);
    ConstMatrix3 D = -A;
    ConstMatrix3 E = eye3 - dt * w_sk + dt_p2_2 * w_sk * w_sk;
    ConstMatrix3 F = -dt * eye3 + dt_p2_2 * w_sk - dt_p3_6 * (w_sk * w_sk);
    ConstMatrix3 C = Ca3 * F;
    
    Fd_.setIdentity();
    Fd_.block<3, 3> (0, 3) = dt * eye3;
    Fd_.block<3, 3> (0, 6) = A;
    Fd_.block<3, 3> (0, 9) = B;
    Fd_.block<3, 3> (0, 12) = -C_eq * dt_p2_2;
    
    Fd_.block<3, 3> (3, 6) = C;
    Fd_.block<3, 3> (3, 9) = D;
    Fd_.block<3, 3> (3, 12) = -C_eq * dt;
    
    Fd_.block<3, 3> (6, 6) = E;
    Fd_.block<3, 3> (6, 9) = F;
    
    calc_Q(dt, StateBuffer_[idx_P_].q_, ew, ea, nav, nbav, nwv, nbwv, 0, nqwvv, nqciv, npicv, Qd_);
    StateBuffer_[idx_P_].P_ = Fd_ * StateBuffer_[(unsigned char)(idx_P_ - 1)].P_ * Fd_.transpose() + Qd_;
    idx_P_++;
}


bool PoseEKF::getStateAtIdx(State* timestate, unsigned char idx)
{
    if (!predictionMade_)
    {
        timestate->time_ = -1;
        return false;
    }
    
    *timestate = StateBuffer_[idx];
    
    return true;
}

unsigned char PoseEKF::getClosestState(State* timestate, double tstamp, double delay)
{
    if (!predictionMade_)
    {
        timestate->time_ = -1;
        return false;
    }
    
    unsigned char idx = (unsigned char)(idx_state_ - 1);
    double timedist = 1e100;
    double timenow = tstamp - delay;
    if(timenow < StateBuffer_[0].time_)
    {
        timestate->time_ = -1;
        return false;
    }
    printf("timenow %lf\n", timenow);
    while (fabs(timenow - StateBuffer_[idx].time_) < timedist) // timedist decreases continuously until best point reached... then rises again
    {
        timedist = fabs(timenow - StateBuffer_[idx].time_);
        printf("state time %lf\n",StateBuffer_[idx].time_);
        idx--;
    }
    idx++;
    printf("idx %d\n", idx);
    printf("idx_state_ %d\n", idx_state_);
    static bool started = false;
    //  if (idx == 1 && !started)
    //    idx = 2;
    started = true;
    
    if (StateBuffer_[idx].time_ == 0)
        return false;
    
    propPToIdx(idx);
    *timestate = StateBuffer_[idx];
    
    return idx;
}

void PoseEKF::propPToIdx(unsigned char idx)
{
    // propagate cov matrix until idx
    if (idx<idx_state_ && (idx_P_<=idx || idx_P_>idx_state_))    //need to propagate some covs
        while (idx!=(unsigned char)(idx_P_-1))
            predictProcessCovariance(StateBuffer_[idx_P_].time_-StateBuffer_[(unsigned char)(idx_P_-1)].time_);
}

bool PoseEKF::applyCorrection(unsigned char idx_delaystate, const ErrorState & res_delayed, double fuzzythres)
{
    static int seq_m = 0;
    //  if (config_.fixed_scale)
    //    if(1)
    //  {
    //    correction_(15) = 0; //scale
    //  }
    
    ////  if (config_.fixed_bias)
    //    if(0)
    //  {
    //    correction_(9) = 0; //acc bias x
    //    correction_(10) = 0; //acc bias y
    //    correction_(11) = 0; //acc bias z
    //    correction_(12) = 0; //gyro bias x
    //    correction_(13) = 0; //gyro bias y
    //    correction_(14) = 0; //gyro bias z
    //  }
    
    ////  if (config_.fixed_calib)
    //  if(1)
    //  {
    //    correction_(19) = 0; //q_ic roll
    //    correction_(20) = 0; //q_ic pitch
    //    correction_(21) = 0; //q_ic yaw
    //    correction_(22) = 0; //p_ci x
    //    correction_(23) = 0; //p_ci y
    //    correction_(24) = 0; //p_ci z
    //  }
    
    // state update:
    State & delaystate = StateBuffer_[idx_delaystate];
    
    const Eigen::Vector3d buff_bw = delaystate.b_w_;
    const Eigen::Vector3d buff_ba = delaystate.b_a_;
    const double buff_L = delaystate.L_;
    const Eigen::Quaterniond buff_qwv = delaystate.q_wv_;
    const Eigen::Quaterniond buff_qci = delaystate.q_ci_;
    const Eigen::Vector3d buff_pic = delaystate.p_ci_;
    
    delaystate.p_ = delaystate.p_ + correction_.block<3, 1> (0, 0);
    delaystate.v_ = delaystate.v_ + correction_.block<3, 1> (3, 0);
    delaystate.b_w_ = delaystate.b_w_ + correction_.block<3, 1> (9, 0);
    delaystate.b_a_ = delaystate.b_a_ + correction_.block<3, 1> (12, 0);
    //  delaystate.L_ = delaystate.L_ + correction_(15);
    //  if (delaystate.L_ < 0)
    //  {
    //    //ROS_WARN_STREAM_THROTTLE(1,"Negative scale detected: " << delaystate.L_ << ". Correcting to 0.1");
    //    delaystate.L_ = 1;
    //  }
    
    Eigen::Quaterniond qbuff_q = quaternionFromSmallAngle(correction_.block<3, 1> (6, 0));
    if (qbuff_q.w() < 0) qbuff_q.coeffs() *= -1;
    delaystate.q_ = delaystate.q_ * qbuff_q;
    delaystate.q_.normalize();
    if (delaystate.q_.w() < 0) delaystate.q_.coeffs() *= -1;
    //  Eigen::Quaterniond qbuff_qwv = quaternionFromSmallAngle(correction_.block<3, 1> (16, 0));
    //  delaystate.q_wv_ = delaystate.q_wv_ * qbuff_qwv;
    //  delaystate.q_wv_.normalize();
    
    //  Eigen::Quaterniond qbuff_qci = quaternionFromSmallAngle(correction_.block<3, 1> (19, 0));
    //  delaystate.q_ci_ = delaystate.q_ci_ * qbuff_qci;
    //  delaystate.q_ci_.normalize();
    
    //  delaystate.p_ci_ = delaystate.p_ci_ + correction_.block<3, 1> (22, 0);
    
    //    // update qbuff_ and check for fuzzy tracking
    //  if (qvw_inittimer_ > nBuff_)
    //  {
    //    // should be unit quaternion if no error
    //    Eigen::Quaterniond errq = delaystate.q_wv_.conjugate() *
    //        Eigen::Quaterniond(
    //            getMedian(qbuff_.block<nBuff_, 1> (0, 3)),
    //            getMedian(qbuff_.block<nBuff_, 1> (0, 0)),
    //            getMedian(qbuff_.block<nBuff_, 1> (0, 1)),
    //            getMedian(qbuff_.block<nBuff_, 1> (0, 2))
    //            );
    
    //    if (std::max(errq.vec().maxCoeff(), -errq.vec().minCoeff()) / fabs(errq.w()) * 2 > fuzzythres) // fuzzy tracking (small angle approx)
    //    {
    //      //ROS_WARN_STREAM_THROTTLE(1,"fuzzy tracking triggered: " << std::max(errq.vec().maxCoeff(), -errq.vec().minCoeff())/fabs(errq.w())*2 << " limit: " << fuzzythres <<"\n");
    
    //      //state_.q_ = buff_q;
    //      delaystate.b_w_ = buff_bw;
    //      delaystate.b_a_ = buff_ba;
    //      delaystate.L_ = buff_L;
    //      delaystate.q_wv_ = buff_qwv;
    //      delaystate.q_ci_ = buff_qci;
    //      delaystate.p_ci_ = buff_pic;
    //      correction_.block<16, 1> (9, 0) = Eigen::Matrix<double, 16, 1>::Zero();
    //      qbuff_q.setIdentity();
    //      qbuff_qwv.setIdentity();
    //      qbuff_qci.setIdentity();
    //    }
    //    else // if tracking ok: update mean and 3sigma of past N q_vw's
    //    {
    //      qbuff_.block<1, 4> (qvw_inittimer_ - nBuff_ - 1, 0) = Eigen::Matrix<double, 1, 4>(delaystate.q_wv_.coeffs());
    //      qvw_inittimer_ = (qvw_inittimer_) % nBuff_ + nBuff_ + 1;
    //    }
    //  }
    //  else // at beginning get mean and 3sigma of past N q_vw's
    //  {
    //    qbuff_.block<1, 4> (qvw_inittimer_ - 1, 0) = Eigen::Matrix<double, 1, 4>(delaystate.q_wv_.coeffs());
    //    qvw_inittimer_++;
    //  }
    
    // idx fiddeling to ensure correct update until now from the past
    idx_time_ = idx_state_;
    idx_state_ = idx_delaystate + 1;
    idx_P_ = idx_delaystate + 1;
    
    // propagate state matrix until now
    while (idx_state_ != idx_time_)
        propagateState(StateBuffer_[idx_state_].time_ - StateBuffer_[(unsigned char)(idx_state_ - 1)].time_);
    
    checkForNumeric(&correction_[0], HLI_EKF_STATE_SIZE, "update");
    
    seq_m++;
    
    return 1;
}


double PoseEKF::getMedian(const Eigen::Matrix<double, nBuff_, 1> & data)
{
    std::vector<double> mediandistvec;
    mediandistvec.reserve(nBuff_);
    for (int i = 0; i < nBuff_; ++i)
        mediandistvec.push_back(data(i));
    
    if (mediandistvec.size() > 0)
    {
        std::vector<double>::iterator first = mediandistvec.begin();
        std::vector<double>::iterator last = mediandistvec.end();
        std::vector<double>::iterator middle = first + std::floor((last - first) / 2);
        std::nth_element(first, middle, last); // can specify comparator as optional 4th arg
        return *middle;
    }
    else
        return 0;
}

#define N_MEAS 6
void PoseEKF::measurementCallback(const Eigen::Vector3d &p, const Eigen::Quaterniond &q, double time_stamp)
{
    
    // init variables
    State state_old;
    Eigen::Matrix<double, N_MEAS, N_STATE> H_old;
    Eigen::Matrix<double, N_MEAS, 1> r_old;
    Eigen::Matrix<double, N_MEAS, N_MEAS> R;
    
    H_old.setZero();
    R.setZero();
    
    // get measurements
    Eigen::Vector3d z_p_ = p;
    Eigen::Quaterniond z_q_ = q;
    
    //  alternatively take fix covariance from reconfigure GUI
    bool use_fixed_covariance_ = true;
    if (use_fixed_covariance_)
    {
        const double s_zp = 0.001 * 0.001;
        const double s_zq = 0.001 * 0.001;
        R = (Eigen::Matrix<double, N_MEAS, 1>() << s_zp, s_zp, s_zp, s_zq, s_zq, s_zq/*, 1e-6*/).finished().asDiagonal();
    }
    
    
    unsigned char idx = getClosestState(&state_old, time_stamp);
    if (state_old.time_ == -1)
        return; // // early abort // //
    
    // get rotation matrices
    Eigen::Matrix3d C_wv = state_old.q_wv_.conjugate().toRotationMatrix();
    Eigen::Matrix3d C_q = state_old.q_.conjugate().toRotationMatrix();
    Eigen::Matrix3d C_ci = state_old.q_ci_.conjugate().toRotationMatrix();
    
    // preprocess for elements in H matrix
    Eigen::Vector3d vecold;
    vecold = (state_old.p_ + C_q.transpose() * state_old.p_ci_) * state_old.L_;
    Eigen::Matrix3d skewold = skew(vecold);
    
    Eigen::Matrix3d pci_sk = skew(state_old.p_ci_);
    
    // construct H matrix using H-blockx :-)
    // position:
    H_old.block<3, 3> (0, 0) = C_wv.transpose() * state_old.L_; // p
    H_old.block<3, 3> (0, 6) = -C_wv.transpose() * C_q.transpose() * pci_sk * state_old.L_; // q
    //  H_old.block<3, 1> (0, 15) = C_wv.transpose() * C_q.transpose() * state_old.p_ci_ + C_wv.transpose() * state_old.p_; // L
    //  H_old.block<3, 3> (0, 16) = -C_wv.transpose() * skewold; // q_wv
    //  H_old.block<3, 3> (0, 22) = C_wv.transpose() * C_q.transpose() * state_old.L_; //p_ci
    
    // attitude
    H_old.block<3, 3> (3, 6) = C_ci; // q
    //  H_old.block<3, 3> (3, 16) = C_ci * C_q; // q_wv
    //  H_old.block<3, 3> (3, 19) = Eigen::Matrix3d::Identity(); //q_ci
    //  H_old(6, 18) = 1.0; // fix vision world yaw drift because unobservable otherwise (see PhD Thesis)
    
    // construct residuals
    // position
    r_old.block<3, 1> (0, 0) = z_p_ - C_wv.transpose() * (state_old.p_ + C_q.transpose() * state_old.p_ci_) * state_old.L_;
    // attitude
    Eigen::Quaterniond q_err;
    q_err = (state_old.q_wv_ * state_old.q_ * state_old.q_ci_).conjugate() * z_q_;
    r_old.block<3, 1> (3, 0) = q_err.vec() / q_err.w() * 2;
    // vision world yaw drift
    q_err = state_old.q_wv_;
    //  r_old(6, 0) = -2 * (q_err.w() * q_err.z() + q_err.x() * q_err.y()) / (1 - 2 * (q_err.y() * q_err.y() + q_err.z() * q_err.z()));
    //  // call update step in core class
    
    //from c to world
    Quaterniond q_cw = state_old.q_ * state_old.q_ci_;
    Vector3d p_cw = state_old.q_.toRotationMatrix() * state_old.p_ci_ + state_old.p_;
    std::cout << "state_old pose" << p_cw.transpose() << std::endl;
    
    applyMeasurement(idx, H_old, r_old, R);
}

bool PoseEKF::getRealPose(Vector3d &pos, Quaterniond &q)
{
    unsigned char id = idx_state_ - 1;
    State& state = StateBuffer_[id];
    
    Quaterniond quat = state.q_ * state.q_ci_;
    Vector3d position = state.q_.toRotationMatrix() * state.p_ci_ + state.p_;
    
    if(quat.norm() < 0.5 || quat.norm() > 1.5 || position.norm() > 10000)
    {
        std::cout << "fusion pose failed!!!!" << std::endl;
        pos << 0,0,0;
        quat.w() = 1;
        quat.x() = 0;
        quat.y() = 0;
        quat.z() = 0;
        return false;
    }
    
    q = quat;
    pos = position;
    return true;
}

