import UIKit
import CoreImage
import PhotosUI

class ViewController: UIViewController, PHPickerViewControllerDelegate {
    
    // UI Elements
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var grainSlider: UISlider!
    @IBOutlet weak var scratchesSlider: UISlider!
    
    // Core Image Context
    let context = CIContext()
    var originalImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Setup sliders
        grainSlider.minimumValue = 0
        grainSlider.maximumValue = 100
        scratchesSlider.minimumValue = 0
        scratchesSlider.maximumValue = 100
    }
    
    // MARK: - Photo Selection
    @IBAction func selectPhoto(_ sender: UIButton) {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        guard let provider = results.first?.itemProvider else { return }
        
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] (image, error) in
                if let selectedImage = image as? UIImage {
                    DispatchQueue.main.async {
                        self?.originalImage = selectedImage
                        self?.imageView.image = selectedImage
                    }
                }
            }
        }
    }
    
    // MARK: - Apply Effects
    @IBAction func applyEffects(_ sender: UIButton) {
        guard let originalImage = originalImage else { return }
        imageView.image = applyPolaroidEffect(to: originalImage)
    }
    
    func applyPolaroidEffect(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Apply Grain Effect
        let grainIntensity = CGFloat(grainSlider.value) / 100.0
        let grainImage = applyGrainEffect(to: ciImage, intensity: grainIntensity)
        
        // Apply Scratch Effect
        let scratchesIntensity = CGFloat(scratchesSlider.value) / 100.0
        let finalImage = applyScratchEffect(to: grainImage, intensity: scratchesIntensity)
        
        // Render the final image
        if let cgImage = context.createCGImage(finalImage, from: finalImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return nil
    }
    
    // MARK: - Grain Effect
    func applyGrainEffect(to image: CIImage, intensity: CGFloat) -> CIImage {
        // Create noise
        let noiseFilter = CIFilter(name: "CIRandomGenerator")!
        guard let noiseImage = noiseFilter.outputImage?.cropped(to: image.extent) else {
            print("Failed to generate noise image.")
            return image
        }
        
        // Scale the noise based on intensity
        let noiseScaled = noiseImage.transformed(by: CGAffineTransform(scaleX: 1.0, y: 1.0))
        
        // Composite the noise over the original image
        let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
        compositeFilter.setValue(noiseScaled, forKey: kCIInputImageKey)
        compositeFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return compositeFilter.outputImage ?? image
    }
    
    // MARK: - Scratch Effect
    func applyScratchEffect(to image: CIImage, intensity: CGFloat) -> CIImage {
        guard intensity > 0 else { return image } // If intensity is 0, return original image
        
        // Create scratches using random generator
        let scratchesFilter = CIFilter(name: "CIRandomGenerator")!
        guard let scratchesImage = scratchesFilter.outputImage?.cropped(to: image.extent) else {
            print("Failed to generate scratches image.")
            return image
        }
        
        // Scale the scratches based on intensity
        let scaleFactor: CGFloat = 0.05 * intensity // Adjust for scratch density
        let scaledScratches = scratchesImage.transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        
        // Create a mask for scratches
        let transparencyFilter = CIFilter(name: "CIColorMatrix")!
        transparencyFilter.setValue(scaledScratches, forKey: kCIInputImageKey)
        transparencyFilter.setValue(CIVector(x: 1, y: 1, z: 1, w: 0.3), forKey: "inputAVector") // Adjust alpha for transparency
        
        guard let transparentScratches = transparencyFilter.outputImage?.cropped(to: image.extent) else {
            print("Failed to apply opacity to scratches.")
            return image
        }
        
        // Composite the scratches over the original image
        let compositeFilter = CIFilter(name: "CISourceOverCompositing")!
        compositeFilter.setValue(transparentScratches, forKey: kCIInputImageKey)
        compositeFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return compositeFilter.outputImage ?? image
    }
}


