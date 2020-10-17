#ifndef HOLOKIT_SDK_POLYNOMIAL_RADIAL_DISTORTION_H_
#define HOLOKIT_SDK_POLYNOMIAL_RADIAL_DISTORTION_H_

#include <array>
#include <vector>

namespace holokit {

// PolynomialRadialDistortion implements a radial distortion based using
// a set of coefficients describing a polynomial function.
// See http://en.wikipedia.org/wiki/Distortion_(optics).
//
// Unless otherwise stated, the units used in this class are tan-angle units
// which can be computed as distance on the screen divided by distance from the
// virtual eye to the screen.
class PolynomialRadialDistortion {
 public:
  // Construct a PolynomialRadialDistortion with coefficients for
  // the radial distortion equation:
  //
  //   p' = p (1 + K1 r^2 + K2 r^4 + ... + Kn r^(2n))
  //
  // where r is the distance in tan-angle units from the optical center,
  // p the input point and p' the output point.
  // The provided vector contains the coefficients for the even monomials
  // in the distortion equation: coefficients[0] is K1, coefficients[1] is K2,
  // etc.  Thus the polynomial used for distortion has degree
  // (2 * coefficients.size()).
  explicit PolynomialRadialDistortion(const std::vector<float>& coefficients);

  // Given a 2d point p, returns the corresponding distorted point.
  // The units of both the input and output points are tan-angle units,
  // which can be computed as the distance on the screen divided by
  // distance from the virtual eye to the screen. For both the input
  // and output points, the intersection of the optical axis of the lens
  // with the screen defines the origin, the x axis points right, and
  // the y axis points up.
  std::array<float, 2> Distort(const std::array<float, 2>& p) const;

  // Given a 2d point p, returns the point that would need to be passed to
  // Distort to get point p (approximately).
  std::array<float, 2> DistortInverse(const std::array<float, 2>& p) const;

 private:
  // Given a radius (measuring distance from the optical axis of the lens),
  // returns the distortion factor for that radius.
  float DistortionFactor(float r_squared) const;

  // Given a radius (measuring distance from the optical axis of the lens),
  // returns the corresponding distorted radius.
  float DistortRadius(float r) const;

  std::vector<float> coefficients_;
};

}  // namespace holokit

#endif  // HOLOKIT_SDK_POLYNOMIAL_RADIAL_DISTORTION_H_
