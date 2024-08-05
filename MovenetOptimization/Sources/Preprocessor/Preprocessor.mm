/* Copyright 2024 The FitsInc Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

#import "Preprocessor.h"
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>

@implementation Preprocessor

+(nonnull NSData *) preprocess:(nullable void *) data
                         width:(int)width
                        height:(int)height
                   bytesPerRow:(int)bytes_per_row {
    cv::Mat image(height, width, CV_8UC4, data, bytes_per_row);
    cv::cvtColor(image, image, cv::COLOR_BGRA2RGB);
    cv::Mat squareImage;
    int inputSize = 256;
    if (width == height) {
        cv::resize(image, squareImage, cv::Size(inputSize, inputSize));
    } else if (width > height) {
        cv::resize(image, image, cv::Size(inputSize, inputSize * height / width));
        int diff = (inputSize - image.rows) / 2;
        cv::copyMakeBorder(image, squareImage, diff, diff, 0, 0, cv::BORDER_CONSTANT, cv::Scalar(0));
    } else {
        cv::resize(image, image, cv::Size(inputSize * width / height, inputSize));
        int diff = (inputSize - image.cols) / 2;
        cv::copyMakeBorder(image, squareImage, 0, 0, diff, diff, cv::BORDER_CONSTANT, cv::Scalar(0));
    }

    squareImage.convertTo(squareImage, CV_32F);
    NSData *nsData = [NSData dataWithBytes:squareImage.data length:squareImage.elemSize()*squareImage.total()];
    return nsData;
}

@end
