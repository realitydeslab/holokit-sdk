#ifndef HOLOKIT_SDK_SENSORS_MEDIAN_FILTER_H_
#define HOLOKIT_SDK_SENSORS_MEDIAN_FILTER_H_

#include <deque>

#include "utils/vector.h"

namespace holokit {

// Fixed window FIFO median filter for vectors of the given dimension = 3.
class MedianFilter {
 public:
  // Creates a median filter of size filter_size.
  // @param filter_size size of the internal filter.
  explicit MedianFilter(size_t filter_size);

  // Adds sample to buffer_ if buffer_ is full it drops the oldest sample.
  void AddSample(const Vector3& sample);

  // Returns true if buffer has filter_size_ sample, false otherwise.
  bool IsValid() const;

  // Returns the median of values store in the internal buffer.
  Vector3 GetFilteredData() const;

  // Resets the filter, removing all samples that have been added.
  void Reset();

 private:
  const size_t filter_size_;
  std::deque<Vector3> buffer_;
  // Contains norms of the elements stored in buffer_.
  std::deque<float> norms_;
};

}  // namespace holokit

#endif  // HOLOKIT_SDK_SENSORS_MEDIAN_FILTER_H_
