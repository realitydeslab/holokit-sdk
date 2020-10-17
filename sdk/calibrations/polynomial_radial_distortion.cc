#include "polynomial_radial_distortion.h"

#include <cmath>
#include <limits>

namespace holokit {

PolynomialRadialDistortion::PolynomialRadialDistortion(
    const std::vector<float>& coefficients)
    : coefficients_(coefficients) {}

float PolynomialRadialDistortion::DistortionFactor(float r_squared) const {
  float r_factor = 1.0f;
  float distortion_factor = 1.0f;

  for (float ki : coefficients_) {
    r_factor *= r_squared;
    distortion_factor += ki * r_factor;
  }

  return distortion_factor;
}

float PolynomialRadialDistortion::DistortRadius(float r) const {
  return r * DistortionFactor(r * r);
}

std::array<float, 2> PolynomialRadialDistortion::Distort(
    const std::array<float, 2>& p) const {
  float distortion_factor = DistortionFactor(p[0] * p[0] + p[1] * p[1]);
  return std::array<float, 2>{distortion_factor * p[0],
                              distortion_factor * p[1]};
}

std::array<float, 2> PolynomialRadialDistortion::DistortInverse(
    const std::array<float, 2>& p) const {
  const float radius = std::sqrt(p[0] * p[0] + p[1] * p[1]);
  if (std::fabs(radius - 0.0f) < std::numeric_limits<float>::epsilon()) {
    return std::array<float, 2>();
  }

  // Based on the shape of typical distortion curves, |radius| / 2 and
  // |radius| / 3 are good initial guesses for the Secant method that will
  // remain within the intended range of the polynomial.
  float r0 = radius / 2.0f;
  float r1 = radius / 3.0f;
  float r2;
  float dr0 = radius - DistortRadius(r0);
  float dr1;
  while (std::fabs(r1 - r0) > 0.0001f /** 0.1mm */) {
    dr1 = radius - DistortRadius(r1);
    r2 = r1 - dr1 * ((r1 - r0) / (dr1 - dr0));
    r0 = r1;
    r1 = r2;
    dr0 = dr1;
  }

  return std::array<float, 2>{(r1 / radius) * p[0], (r1 / radius) * p[1]};
}

}  // namespace holokit
