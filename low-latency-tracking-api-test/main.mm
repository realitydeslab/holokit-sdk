//
//  main.cpp
//  low-latency-tracking-api-test
//
//  Created by Yuchen on 2021/8/13.
//

#include <fstream>
#include <string>
#include <stdlib.h>
#include "low-latency-tracking/low_latency_tracking_api.h"
#include <vector>

enum DataType {
    ARKit,
    Accel,
    Gyro
};

struct DataInterface  {
public:
    double received_time;
    DataType data_type;
    void* data;
};

bool dataCompare(const DataInterface& a, const DataInterface& b) {
    return a.received_time < b.received_time;
}

std::vector<DataInterface> data_queue;
std::vector<DataInterface> arkit_data_queue;
std::vector<DataInterface> accel_data_queue;
std::vector<DataInterface> gyro_data_queue;

const char *arkit_file_path = "/tmp/ARposes.txt";
const char *accel_file_path = "/tmp/Accel.txt";
const char *gyro_file_path = "/tmp/Gyro.txt";


double read_double(std::istringstream& ss) {
    std::string s;
    std::getline(ss, s, ',');
    double d;
    std::stringstream ss2(s);
    ss2 >> d;
    return d;
}

void read_arkit_data() {
    std::string line;
    std::ifstream arkit_file(arkit_file_path);
    while (std::getline(arkit_file, line)) {
        std::istringstream ss(line);
                
        double arkit_receive_time = read_double(ss);
        double arkit_sensor_time = read_double(ss);
        double arkit_position_x = read_double(ss);
        double arkit_position_y = read_double(ss);
        double arkit_position_z = read_double(ss);
        
        double arkit_quaternion_w = read_double(ss);
        double arkit_quaternion_x = read_double(ss);
        double arkit_quaternion_y = read_double(ss);
        double arkit_quaternion_z = read_double(ss);
        
        DataInterface* data_ptr = new DataInterface();
        holokit::ARKitData* arkit_data_ptr = new holokit::ARKitData();

        data_ptr->received_time = arkit_receive_time;
        data_ptr->data_type = ARKit;
        data_ptr->data = arkit_data_ptr;
        
        arkit_data_ptr->sensor_timestamp = arkit_sensor_time;
        arkit_data_ptr->position = Eigen::Vector3d(arkit_position_x, arkit_position_y, arkit_position_z);
        arkit_data_ptr->rotation = Eigen::Quaterniond(arkit_quaternion_w, arkit_quaternion_x, arkit_quaternion_y, arkit_quaternion_z);
        
        arkit_data_queue.push_back(*data_ptr);
        data_queue.push_back(*data_ptr);
    }
}

void read_accel_data() {
    std::string line;
    std::ifstream accel_file(accel_file_path);
    while (std::getline(accel_file, line)) {
        std::istringstream ss(line);
        
        double accel_receive_time = read_double(ss);
        double accel_sensor_time = read_double(ss);
        double accel_x = read_double(ss);
        double accel_y = read_double(ss);
        double accel_z = read_double(ss);
        
        DataInterface* data_ptr = new DataInterface();
        holokit::AccelerometerData* accel_data_ptr = new holokit::AccelerometerData();

        data_ptr->received_time = accel_receive_time;
        data_ptr->data_type = Accel;
        data_ptr->data = accel_data_ptr;
        
        accel_data_ptr->sensor_timestamp = accel_sensor_time;
        accel_data_ptr->acceleration = Eigen::Vector3d(accel_x, accel_y, accel_z);
        
        accel_data_queue.push_back(*data_ptr);
        data_queue.push_back(*data_ptr);
//        std::cout << accel_data_ptr->acceleration << std::endl;
    }
}


void read_gyro_data() {
    std::string line;
    std::ifstream gyro_file(gyro_file_path);
    while (std::getline(gyro_file, line)) {
        std::istringstream ss(line);
        
        double gyro_receive_time = read_double(ss);
        double gyro_sensor_time = read_double(ss);
        double gyro_x = read_double(ss);
        double gyro_y = read_double(ss);
        double gyro_z = read_double(ss);
        
        DataInterface* data_ptr = new DataInterface();
        holokit::GyroData* gyro_data_ptr = new holokit::GyroData();

        data_ptr->received_time = gyro_receive_time;
        data_ptr->data_type = Gyro;
        data_ptr->data = gyro_data_ptr;
        
        gyro_data_ptr->sensor_timestamp = gyro_sensor_time;
        gyro_data_ptr->rotationRate = Eigen::Vector3d(gyro_x, gyro_y, gyro_z);
        
        gyro_data_queue.push_back(*data_ptr);
        data_queue.push_back(*data_ptr);
//        std::cout << gyro_data_ptr->rotationRate << std::endl;
    }
}



int main(int argc, const char * argv[]) {
    
    const double FIXED_LAG_TIME = 0.0166;
    

    // Open the file.
    
    std::cout <<"hi";
    read_arkit_data();
    read_accel_data();
    read_gyro_data();
    
    std::cout <<"read_end";
    
    sort(arkit_data_queue.begin(), arkit_data_queue.end(), dataCompare);
    sort(accel_data_queue.begin(), accel_data_queue.end(), dataCompare);
    sort(gyro_data_queue.begin(), gyro_data_queue.end(), dataCompare);
    sort(data_queue.begin(), data_queue.end(), dataCompare);

    holokit::LowLatencyTrackingApi::GetInstance()->Clear();

    for (int i = 0; i < arkit_data_queue.size(); i++) {
        
        holokit::ARKitData* target_arkit_data_ptr = (holokit::ARKitData*) arkit_data_queue[i].data;
        
        Eigen::Vector3d target_position = target_arkit_data_ptr->position;
        Eigen::Quaterniond target_rotation = target_arkit_data_ptr->rotation;
        double target_arkit_sensor_time = target_arkit_data_ptr->sensor_timestamp;
        
        holokit::LowLatencyTrackingApi::GetInstance()->Clear();
        
        for (int j = 0; j < data_queue.size() && data_queue[j].received_time < target_arkit_sensor_time; j++) {
            if (data_queue[j].data_type == ARKit)
            {
                holokit::ARKitData* arkit_data_ptr = (holokit::ARKitData*) data_queue[j].data;
                holokit::LowLatencyTrackingApi::GetInstance()->OnARKitDataUpdated(*arkit_data_ptr);
            }
            else if (data_queue[j].data_type == Accel)
            {
                holokit::AccelerometerData* accel_data_ptr = (holokit::AccelerometerData*) data_queue[j].data;
                holokit::LowLatencyTrackingApi::GetInstance()->OnAccelerometerDataUpdated(*accel_data_ptr);
            } else if (data_queue[j].data_type == Gyro)
            {
                holokit::GyroData* gyro_data_ptr = (holokit::GyroData*) data_queue[j].data;
                holokit::LowLatencyTrackingApi::GetInstance()->OnGyroDataUpdated(*gyro_data_ptr);
            }
        }
        Eigen::Vector3d predicted_position;
        Eigen::Quaterniond predicted_rotation;
        holokit::LowLatencyTrackingApi::GetInstance()->GetPose(target_arkit_sensor_time, predicted_position, predicted_rotation);
        std::cout << "Position error: " << (predicted_position - target_position).norm() << std::endl;
        std::cout << "Rotation error: " << predicted_rotation.angularDistance(target_rotation) / M_PI * 180 << std::endl << std::endl ;
        
    }

    
    
    
    return 0;
}
