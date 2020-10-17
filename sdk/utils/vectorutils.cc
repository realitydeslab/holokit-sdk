
#include "utils/vectorutils.h"

namespace holokit {

// Returns the dot (inner) product of two Vectors.
double Dot(const Vector<3>& v0, const Vector<3>& v1) {
  return v0[0] * v1[0] + v0[1] * v1[1] + v0[2] * v1[2];
}

// Returns the dot (inner) product of two Vectors.
double Dot(const Vector<4>& v0, const Vector<4>& v1) {
  return v0[0] * v1[0] + v0[1] * v1[1] + v0[2] * v1[2] + v0[3] * v1[3];
}

// Returns the 3-dimensional cross product of 2 Vectors. Note that this is
// defined only for 3-dimensional Vectors.
Vector<3> Cross(const Vector<3>& v0, const Vector<3>& v1) {
  return Vector<3>(v0[1] * v1[2] - v0[2] * v1[1], v0[2] * v1[0] - v0[0] * v1[2],
                   v0[0] * v1[1] - v0[1] * v1[0]);
}

}  // namespace holokit
