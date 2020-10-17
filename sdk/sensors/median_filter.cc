#include "sensors/median_filter.h"

#include <algorithm>
#include <vector>

#include "utils/vector.h"
#include "utils/vectorutils.h"

namespace holokit {

MedianFilter::MedianFilter(size_t filter_size) : filter_size_(filter_size) {}

void MedianFilter::AddSample(const Vector3& sample) {
  buffer_.push_back(sample);
  norms_.push_back(Length(sample));
  if (buffer_.size() > filter_size_) {
    buffer_.pop_front();
    norms_.pop_front();
  }
}

bool MedianFilter::IsValid() const { return buffer_.size() == filter_size_; }

Vector3 MedianFilter::GetFilteredData() const {
  std::vector<float> norms(norms_.begin(), norms_.end());

  // Get median of value of the norms.
  std::nth_element(norms.begin(), norms.begin() + filter_size_ / 2,
                   norms.end());
  const float median_norm = norms[filter_size_ / 2];

  // Get median value based on their norm.
  auto median_it = buffer_.begin();
  for (const auto norm : norms_) {
    if (norm == median_norm) {
      break;
    }
    ++median_it;
  }

  return *median_it;
}

void MedianFilter::Reset() {
  buffer_.clear();
  norms_.clear();
}

}  // namespace holokit
