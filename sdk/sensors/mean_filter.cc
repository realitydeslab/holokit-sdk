#include "sensors/mean_filter.h"

namespace holokit {

MeanFilter::MeanFilter(size_t filter_size) : filter_size_(filter_size) {}

void MeanFilter::AddSample(const Vector3& sample) {
  buffer_.push_back(sample);
  if (buffer_.size() > filter_size_) {
    buffer_.pop_front();
  }
}

bool MeanFilter::IsValid() const { return buffer_.size() == filter_size_; }

Vector3 MeanFilter::GetFilteredData() const {
  // Compute mean of the samples stored in buffer_.
  Vector3 mean = Vector3::Zero();
  for (auto sample : buffer_) {
    mean += sample;
  }

  return mean / static_cast<double>(filter_size_);
}

}  // namespace holokit
