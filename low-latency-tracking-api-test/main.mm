//
//  main.cpp
//  low-latency-tracking-api-test
//
//  Created by Yuchen on 2021/8/13.
//

#include <iostream>
#include <fstream>
#include <string>
#include <stdlib.h>
#include "low-latency-tracking/low_latency_tracking_api.h"

int main(int argc, const char * argv[]) {
    
    const double FIXED_LAG_TIME = 70.0 + 16.6;
    const int SKIP_FRAME_COUNT = 60;
    
    const char *arkit_file_path = "";
    const char *accel_file_path = "";
    const char *gyro_file_path = "";
    
    // Open the file.
    std::ifstream arkit_file(arkit_file_path);
    
    int total_frame_count = 0;
    int current_frame_count = 0;
    
    std::string line;
    
    // Calculate the total number of frames in arkit data file.
    if (arkit_file.is_open()) {
        while (std::getline(arkit_file, line)) {
            ++total_frame_count;
        }
        arkit_file.close();
    } else {
        std::cout << "Cannot open arkit file" << std::endl;
        return 0;
    }
    
    double target_receive_time, target_sensor_time;
    double target_position_x, target_position_y, target_position_z;
    double target_quaternion_w, target_quaternion_x, target_quaternion_y, target_quaternion_z;
    
    arkit_file(arkit_file_path);
    
    holokit::LowLatencyTrackingApi::GetInstance()->Activate();
    
    if (arkit_file.is_open()) {
        while (arkit_file >> target_receive_time >> target_sensor_time >>
               target_position_x >> target_position_y >> target_position_z >>
               target_quaternion_w >> target_quaternion_x >> target_quaternion_y >> target_quaternion_z) {
            
            current_frame_count++;
            std::cout << "Frame count: " << current_frame_count << std::endl << " (" << current_frame_count / total_frame_count << ")";
            if (current_frame_count < SKIP_FRAME_COUNT) {
                std::cout << "This frame is skipped" << std::endl;
                continue;
            }
            
            // Input all available arkit data.
            std::ifstream arkit_file_input(arkit_file_path);
            if (arkit_file_input.is_open()) {
                double arkit_receive_time, arkit_sensor_time;
                double arkit_position_x, arkit_position_y, arkit_position_z;
                double arkit_quaternion_w, arkit_quaternion_x, arkit_quaternion_y, arkit_quaternion_z;
                while (arkit_file_input >> arkit_receive_time >> arkit_sensor_time >>
                    arkit_position_x >> arkit_position_y >> arkit_position_z >>
                       arkit_quaternion_w >> arkit_quaternion_x >> arkit_quaternion_y >> arkit_quaternion_z) {
                    if (arkit_receive_time > target_receive_time - FIXED_LAG_TIME) {
                        break;
                    }
                    holokit::ARKitData arkitData;
                    arkitData.sensor_timestamp = arkit_sensor_time;
                    arkitData.position = Eigen::Vector3d(arkit_position_x, arkit_position_y, arkit_position_z);
                    arkitData.rotation = Eigen::Quaterniond(arkit_quaternion_w, arkit_quaternion_x, arkit_quaternion_y, arkit_quaternion_z);
                    // TODO: intrinsic matrix
                    
                }
                arkit_file_input.close();
            } else {
                std::cout << "Cannot open arkit data file" << std::endl;
            }
            
            // Input all available accel data.
            std::ifstream accel_file_input(accel_file_path);
            if (accel_file_input.is_open()) {
                double accel_receive_time, accel_sensor_time;
                double accel_x, accel_y, accel_z;
                while(accel_file_input >> accel_receive_time << accel_sensor_time >> accel_x >> accel_y >> accel_z) {
                    if (accel_receive_time > target_receive_time - FIXED_LAG_TIME) {
                        break;
                    }
                    holokit::AccelerometerData accelData;
                    accelData.sensor_timestamp = accel_sensor_time;
                    accelData.acceleration = Eigen::Vector3d(accel_x, accel_y, accel_z);
                }
                accel_file_input.close();
            } else {
                std::cout << "Cannot open accel data file" << std::endl;
            }
            
            // Input all available gyro data.
            std::ifstream gyro_file_input(gyro_file_path);
            if (gyro_file_input.is_open()) {
                double gyro_receive_time, gyro_sensor_time;
                double gyro_x, gyro_y, gyro_z;
                while(gyro_file_input >> gyro_receive_time >> gyro_sensor_time >>
                      gyro_x >> gyro_y >> gyro_z) {
                    if (gyro_receive_time > target_receive_time - FIXED_LAG_TIME) {
                        break;
                    }
                    holokit::GyroData gyroData;
                    gyroData.sensor_timestamp = gyro_sensor_time;
                    gyroData.rotationRate = Eigen::Vector3d(gyro_x, gyro_y, gyro_z);
                }
                gyro_file_input.close();
            } else {
                std::cout << "Cannot open gyro data file" << std::endl;
            }
            
            // Make the prediction.
            Eigen::Vector3d predicted_position;
            Eigen::Quaterniond predicted_rotation;
            holokit::LowLatencyTrackingApi::GetInstance()->GetPose(target_receive_time, predicted_position, predicted_rotation);
            std::cout << "Position error: (" << abs(predicted_position(0), target_position_x) << ", " << abs(predicted_position(1), target_position_y) << ", " << abs(predicted_position(2), target_position_z) << ")" << std::endl;
            std::cout << "Rotation error: (" << abs(predicted_rotation(0), target_quaternion_w) << ", " << abs(predicted_rotation(1), target_quaternion_x) << ", " << abs(predicted_rotation(2), target_quaternion_y) << ", " << abs(predicted_rotation(3), target_quaternion_z) << ")" << std::endl;
            
            // Clear all data.
            holokit::LowLatencyTrackingApi::GetInstance()->Clear();
        }
    }
    
    return 0;
}
