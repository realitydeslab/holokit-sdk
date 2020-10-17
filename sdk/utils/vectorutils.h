
#ifndef HOLOKIT_SDK_UTIL_VECTORUTILS_H_
#define HOLOKIT_SDK_UTIL_VECTORUTILS_H_

//
// This file contains free functions that operate on Vector instances.
//

#include <cmath>

#include "utils/vector.h"

namespace holokit {

// Returns the dot (inner) product of two Vectors.
double Dot(const Vector<3>& v0, const Vector<3>& v1);

// Returns the dot (inner) product of two Vectors.
double Dot(const Vector<4>& v0, const Vector<4>& v1);

// Returns the 3-dimensional cross product of 2 Vectors. Note that this is
// defined only for 3-dimensional Vectors.
Vector<3> Cross(const Vector<3>& v0, const Vector<3>& v1);

// Returns the square of the length of a Vector.
template <int Dimension>
double LengthSquared(const Vector<Dimension>& v) {
  return Dot(v, v);
}

// Returns the geometric length of a Vector.
template <int Dimension>
double Length(const Vector<Dimension>& v) {
  return sqrt(LengthSquared(v));
}

// the Vector untouched and returns false.
template <int Dimension>
bool Normalize(Vector<Dimension>* v) {
  const double len = Length(*v);
  if (len == 0) {
    return false;
  } else {
    (*v) /= len;
    return true;
  }
}

// Returns a unit-length version of a Vector. If the given Vector has no
// length, this returns a Zero() Vector.
template <int Dimension>
Vector<Dimension> Normalized(const Vector<Dimension>& v) {
  Vector<Dimension> result = v;
  if (Normalize(&result))
    return result;
  else
    return Vector<Dimension>::Zero();
}

}  // namespace holokit

#endif  // HOLOKIT_SDK_UTIL_VECTORUTILS_H_
