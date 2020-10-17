#ifndef HOLOKIT_SDK_SENSORS_MEAN_FILTER_H_
#define HOLOKIT_SDK_SENSORS_MEAN_FILTER_H_

#include <deque>

#include "utils/vector.h"

namespace holokit {

// Fixed window FIFO mean filter for vectors of the given dimension.
class MeanFilter {
 public:
  // Create a mean filter of size filter_size.
  // @param filter_size size of the internal filter.
  explicit MeanFilter(size_t filter_size);

  // Add sample to buffer_ if buffer_ is full it drop the oldest sample.
  void AddSample(const Vector3& sample);

  // Returns true if buffer has filter_size_ sample, false otherwise.
  bool IsValid() const;

  // Returns the mean of values stored in the internal buffer.
  Vector3 GetFilteredData() const;

 private:
  const size_t filter_size_;
  std::deque<Vector3> buffer_;
};

}  // namespace holokit

#endif  // HOLOKIT_SDK_SENSORS_MEAN_FILTER_H_
