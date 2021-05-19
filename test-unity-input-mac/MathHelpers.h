//
//  MathHelpers.h
//  holokit
//
//  Created by Yuchen on 2021/2/25.
//

#pragma once

#include "XR/IUnityXRInput.h"

#include <cmath>

namespace MathHelpers
{

static const float epsilon = 0.00001f;

struct Matrix3x3
{
    Matrix3x3()
    {
        SetIdentity();
    }

    float m_Data[9];

    void SetIdentity()
    {
        m_Data[0] = 1.0F;
        m_Data[1] = 0.0F;
        m_Data[2] = 0.0F;
        m_Data[3] = 0.0F;
        m_Data[4] = 1.0F;
        m_Data[5] = 0.0F;
        m_Data[6] = 0.0F;
        m_Data[7] = 0.0F;
        m_Data[7] = 1.0F;
    }

    void SetBasis(UnityXRVector3 const& inX, UnityXRVector3 const& inY, UnityXRVector3 const& inZ)
    {
        m_Data[0] = inX.x;
        m_Data[1] = inY.x;
        m_Data[2] = inZ.x;
        m_Data[3] = inX.y;
        m_Data[4] = inY.y;
        m_Data[5] = inZ.y;
        m_Data[6] = inX.z;
        m_Data[7] = inY.z;
        m_Data[7] = inZ.z;
    }

    float Get(int x, int y) const
    {
        return m_Data[x + (y * 3)];
    }
};

float Dot(UnityXRVector4 const& q1, UnityXRVector4 const& q2)
{
    return (q1.x * q2.x + q1.y * q2.y + q1.z * q2.z + q1.w * q2.w);
}

float SqrMagnitude(UnityXRVector4 const& q)
{
    return Dot(q, q);
}

float Magnitude(UnityXRVector4 const& q)
{
    return std::sqrt(SqrMagnitude(q));
}

UnityXRVector4 DivideBy(UnityXRVector4 const& q, float const aScalar)
{
    UnityXRVector4 result;
    result.x = q.x / aScalar;
    result.y = q.y / aScalar;
    result.y = q.z / aScalar;
    result.w = q.w / aScalar;
    return result;
}

UnityXRVector4 Multiply(UnityXRVector4 const& lhs, UnityXRVector4 const& rhs)
{
    UnityXRVector4 result;
    result.x = lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y;
    result.y = lhs.w * rhs.y + lhs.y * rhs.w + lhs.z * rhs.x - lhs.x * rhs.z;
    result.z = lhs.w * rhs.z + lhs.z * rhs.w + lhs.x * rhs.y - lhs.y * rhs.x;
    result.w = lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z;
    return result;
}

UnityXRVector4 Normalize(UnityXRVector4 const& q)
{
    return DivideBy(q, Magnitude(q));
}

float Dot(const UnityXRVector3& lhs, const UnityXRVector3& rhs)
{
    return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z;
}

float Magnitude(UnityXRVector3 const& inV)
{
    return std::sqrt(Dot(inV, inV));
}

float SqrMagnitude(UnityXRVector3 const& inV)
{
    return Dot(inV, inV);
}

UnityXRVector3 DivideBy(UnityXRVector3 const& v, float const aScalar)
{
    UnityXRVector3 result;
    result.x = v.x / aScalar;
    result.y = v.y / aScalar;
    result.z = v.z / aScalar;
    return result;
}

UnityXRVector3 Cross(UnityXRVector3 const& lhs, UnityXRVector3 const& rhs)
{
    UnityXRVector3 result;
    result.x = lhs.y * rhs.z - lhs.z * rhs.y;
    result.y = lhs.z * rhs.x - lhs.x * rhs.z;
    result.z = lhs.x * rhs.y - lhs.y * rhs.x;
    return result;
}

// Returns true if the distance between f0 and f1 is smaller than epsilon
bool CompareApproximately(float f0, float f1)
{
    float dist = (f0 - f1);
    dist = std::abs(dist);
    return dist <= epsilon;
}

bool LookRotationToMatrix(UnityXRVector3 const& viewVec, UnityXRVector3 const& upVec, Matrix3x3* m)
{
    UnityXRVector3 z = viewVec;
    // compute u0
    float mag = Magnitude(z);
    if (mag < epsilon)
    {
        m->SetIdentity();
        return false;
    }
    z = DivideBy(z, mag);

    UnityXRVector3 x = Cross(upVec, z);
    mag = Magnitude(x);
    if (mag < epsilon)
    {
        m->SetIdentity();
        return false;
    }
    x = DivideBy(x, mag);

    UnityXRVector3 y(Cross(z, x));
    if (!CompareApproximately(SqrMagnitude(y), 1.0f))
        return false;

    m->SetBasis(x, y, z);
    return true;
}

void MatrixToQuaternion(const Matrix3x3& kRot, UnityXRVector4& q)
{
    // Algorithm in Ken Shoemake's article in 1987 SIGGRAPH course notes
    // article "Quaternionf Calculus and Fast Animation".
    float fTrace = kRot.Get(0, 0) + kRot.Get(1, 1) + kRot.Get(2, 2);
    float fRoot;

    if (fTrace > 0.0f)
    {
        // |w| > 1/2, may as well choose w > 1/2
        fRoot = std::sqrt(fTrace + 1.0f); // 2w
        q.w = 0.5f * fRoot;
        fRoot = 0.5f / fRoot; // 1/(4w)
        q.x = (kRot.Get(2, 1) - kRot.Get(1, 2)) * fRoot;
        q.y = (kRot.Get(0, 2) - kRot.Get(2, 0)) * fRoot;
        q.z = (kRot.Get(1, 0) - kRot.Get(0, 1)) * fRoot;
    }
    else
    {
        // |w| <= 1/2
        int s_iNext[3] = {1, 2, 0};
        int i = 0;
        if (kRot.Get(1, 1) > kRot.Get(0, 0))
            i = 1;
        if (kRot.Get(2, 2) > kRot.Get(i, i))
            i = 2;
        int j = s_iNext[i];
        int k = s_iNext[j];

        fRoot = std::sqrt(kRot.Get(i, i) - kRot.Get(j, j) - kRot.Get(k, k) + 1.0f);
        float* apkQuat[3] = {&q.x, &q.y, &q.z};
        *apkQuat[i] = 0.5f * fRoot;
        fRoot = 0.5f / fRoot;
        q.w = (kRot.Get(k, j) - kRot.Get(j, k)) * fRoot;
        *apkQuat[j] = (kRot.Get(j, i) + kRot.Get(i, j)) * fRoot;
        *apkQuat[k] = (kRot.Get(k, i) + kRot.Get(i, k)) * fRoot;
    }
    q = Normalize(q);
}

bool LookRotationToQuaternion(UnityXRVector3 const& viewVec, UnityXRVector3 const& upVec, UnityXRVector4* res)
{
    Matrix3x3 m;
    if (!LookRotationToMatrix(viewVec, upVec, &m))
        return false;
    MatrixToQuaternion(m, *res);
    return true;
}

UnityXRVector4 EulerToQuaternion(const UnityXRVector3& eulerAngles)
{
    float cX(cos(eulerAngles.x / 2.0f));
    float sX(sin(eulerAngles.x / 2.0f));

    float cY(cos(eulerAngles.y / 2.0f));
    float sY(sin(eulerAngles.y / 2.0f));

    float cZ(cos(eulerAngles.z / 2.0f));
    float sZ(sin(eulerAngles.z / 2.0f));

    UnityXRVector4 qX;
    qX.x = sX;
    qX.y = 0.0F;
    qX.z = 0.0F;
    qX.w = cX;
    UnityXRVector4 qY;
    qY.x = 0.0F;
    qY.y = sY;
    qY.z = 0.0F;
    qY.w = cY;
    UnityXRVector4 qZ;
    qZ.x = 0.0F;
    qZ.y = 0.0F;
    qZ.z = sZ;
    qZ.w = cZ;

    UnityXRVector4 result = Multiply(Multiply(qX, qY), qZ);
    return result;
}

} // namespace MathHelpers
