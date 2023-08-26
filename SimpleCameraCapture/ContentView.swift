//
//  ContentView.swift
//  SimpleCameraCapture
//
//  Created by Saikat Kumar Dey on 26/08/23.
//


import SwiftUI
import AVFoundation

struct ContentView: View {
    var body: some View {
        CameraView()
    }
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var frameCount = 0  // Initialize a frame counter
    let frameInterval = 1  // Set the frame interval to N, e.g., 5 frames
    var objectDetection = ObjectDetection()
//
//    var previousPredictions = [[Prediction]]()  // Buffer to store past predictions
//    let frameBufferLength = 5  // Number of past frames to consider for averaging
//
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupCaptureSession()
        }
    }
    func setupCaptureSession() {
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        DispatchQueue.main.async { [weak self] in
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = self?.view.layer.bounds ?? CGRect.zero
            previewLayer.videoGravity = .resizeAspectFill
            self?.view.layer.addSublayer(previewLayer)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(videoOutput)
        
        captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            frameCount += 1  // Increment the frame counter
            
            if frameCount % frameInterval == 0 {  // Check if it's the Nth frame
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                let predictions = objectDetection.detectObjects(pixelBuffer: pixelBuffer)
                // TODO: add frame averaging logic here
                DispatchQueue.main.async {
                    self.updateUI(with: predictions)
                }
            }
    }
    
    // Function to average the predictions over the last N frames
    func averagePredictions(_ predictionsBuffer: [[Prediction]]) -> [Prediction] {
        var averagedPredictions = [String: Prediction]()
        
        for predictions in predictionsBuffer {
            for prediction in predictions {
                if let existingPrediction = averagedPredictions[prediction.label] {
                    let newBBox = CGRect(
                        x: (existingPrediction.bbox.origin.x + prediction.bbox.origin.x) / 2,
                        y: (existingPrediction.bbox.origin.y + prediction.bbox.origin.y) / 2,
                        width: (existingPrediction.bbox.width + prediction.bbox.width) / 2,
                        height: (existingPrediction.bbox.height + prediction.bbox.height) / 2
                    )
                    let newConfidence = (existingPrediction.confidence + prediction.confidence) / 2
                    averagedPredictions[prediction.label] = Prediction(label: prediction.label, bbox: newBBox, confidence: newConfidence)
                } else {
                    averagedPredictions[prediction.label] = prediction
                }
            }
        }
        
        return Array(averagedPredictions.values)
    }
    
    func updateUI(with predictions: [Prediction]) {
        // Remove existing annotations
        view.layer.sublayers?.removeSubrange(1...)
        
        let viewWidth = view.bounds.width
        let viewHeight = view.bounds.height
        
        if(predictions.count > 0){
            print("Number of objects: \(predictions.count)")
        }
        
        for prediction in predictions {
            // Transform bounding box
            let transformedRect = CGRect(
                x: prediction.bbox.origin.x * viewWidth,
                y: (1 - prediction.bbox.origin.y) * viewHeight - (prediction.bbox.height * viewHeight),
                width: prediction.bbox.width * viewWidth,
                height: prediction.bbox.height * viewHeight
            )
            
            // Create bounding box
            let boundingBox = CAShapeLayer()
            boundingBox.path = UIBezierPath(rect: transformedRect).cgPath
            boundingBox.strokeColor = UIColor.green.cgColor
            boundingBox.fillColor = UIColor.clear.cgColor
            boundingBox.lineWidth = 4
            view.layer.addSublayer(boundingBox)
            
            // Create label
            let textLayer = CATextLayer()
            textLayer.string = "\(prediction.label) \(String(format: "%.2f", prediction.confidence))"
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.fontSize = 15
            textLayer.frame = CGRect(x: transformedRect.origin.x, y: transformedRect.origin.y - 30, width: 200, height: 50)
            view.layer.addSublayer(textLayer)
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> some UIViewController {
        return CameraViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // Update logic
    }
}
