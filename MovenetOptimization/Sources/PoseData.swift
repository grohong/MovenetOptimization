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

import UIKit

// MARK: Detection result

/// An enum describing a body part (e.g. nose, left eye etc.).
public enum BodyPart: String, CaseIterable {
    case nose = "nose"
    case leftEye = "left eye"
    case rightEye = "right eye"
    case leftEar = "left ear"
    case rightEar = "right ear"
    case leftShoulder = "left shoulder"
    case rightShoulder = "right shoulder"
    case leftElbow = "left elbow"
    case rightElbow = "right elbow"
    case leftWrist = "left wrist"
    case rightWrist = "right wrist"
    case leftHip = "left hip"
    case rightHip = "right hip"
    case leftKnee = "left knee"
    case rightKnee = "right knee"
    case leftAnkle = "left ankle"
    case rightAnkle = "right ankle"

    /// Get the index of the body part in the array returned by pose estimation models.
    public var position: Int {
        return BodyPart.allCases.firstIndex(of: self) ?? 0
    }
}

/// A body keypoint (e.g. nose) 's detection result.
public struct KeyPoint {
    public var bodyPart: BodyPart
    public var coordinate: CGPoint
    public var score: Float32
}

/// A person detected by a pose estimation model.
public struct Person {
    public var keyPoints: [KeyPoint]
    public var score: Float32
    public var isAllMatched: Bool
}
