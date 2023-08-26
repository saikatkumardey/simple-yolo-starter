//
//  ObjectDetection.swift
//  SimpleCameraCapture
//
//  Created by Saikat Kumar Dey on 26/08/23.
//

import CoreML
import Vision

struct Prediction {
    var label: String
    var bbox: CGRect
    var confidence: Double = 0.0
}
// TODO: allow tinkering with these values from settings
class ThresholdProvider: MLFeatureProvider {
    open var values = [
        "iouThreshold": MLFeatureValue(double: UserDefaults.standard.double(forKey: "iouThreshold")),
        "confidenceThreshold": MLFeatureValue(double: UserDefaults.standard.double(forKey: "confidenceThreshold"))
    ]
    
    var featureNames: Set<String> {
        return Set(values.keys)
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return values[featureName]
    }
}

class ObjectDetection {
    private var model: VNCoreMLModel?
    private var thresholdProvider = ThresholdProvider()
    
    init() {
        do {
            model = try VNCoreMLModel(for: yolov8s.init(configuration: MLModelConfiguration()).model)
        } catch {
            print("Error initializing model: \(error)")
        }
    }
    
    func detectObjects(pixelBuffer: CVPixelBuffer) -> [Prediction] {
        var predictions: [Prediction] = []
        
        if let model = model {
            let request = VNCoreMLRequest(model: model) { request, error in
                DispatchQueue.main.async{
                    if let results = request.results as? [VNRecognizedObjectObservation] {
                        self.thresholdProvider.values = ["iouThreshold": MLFeatureValue(double: 0.7),
                                                         "confidenceThreshold": MLFeatureValue(double: 0.5)]
                        model.featureProvider = self.thresholdProvider
                        for result in results {
                            
                            let topLabelObservation = result.labels[0]
                            let label = topLabelObservation.identifier
                            let confidence = topLabelObservation.confidence
                            let bbox = result.boundingBox
                            
                            predictions.append(Prediction(label: label, bbox: bbox, confidence: Double(confidence)))
                        }
                    }
                }
            }
            
            // orientation: .right is required to correctly interpret the input buffer. Very important!
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,orientation: .right, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform detection: \(error)")
            }
        }
        
        return predictions
    }
}
