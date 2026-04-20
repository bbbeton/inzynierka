# MoveNet Thunder Setup Instructions

This app uses MoveNet Thunder for pose estimation before trick classification. Follow these steps to set up the MoveNet Thunder model:

## Step 1: Download MoveNet Thunder Model

1. Visit the TensorFlow Hub page for MoveNet Thunder:
   https://tfhub.dev/google/movenet/singlepose/thunder/4

2. Download the TFLite model. You can use one of these methods:

   **Option A: Direct Download**
   - Click on the "Download" button or use the direct link to download the `.tflite` file
   - The model file should be named something like `movenet_singlepose_thunder_4.tflite`

   **Option B: Using Python Script**
   ```python
   import tensorflow_hub as hub
   import tensorflow as tf
   
   # Load the model
   model = hub.load("https://tfhub.dev/google/movenet/singlepose/thunder/4")
   
   # Convert to TFLite
   converter = tf.lite.TFLiteConverter.from_saved_model(model)
   tflite_model = converter.convert()
   
   # Save the model
   with open('movenet_thunder.tflite', 'wb') as f:
       f.write(tflite_model)
   ```

## Step 2: Place Model in Assets Folder

1. Copy the downloaded `.tflite` file to `flatground_app/assets/`
2. Rename it to `movenet_thunder.tflite` (if it has a different name)

## Step 3: Verify Asset Configuration

The `pubspec.yaml` file should already include the model in the assets section:
```yaml
assets:
  - assets/trick_classifier.tflite
  - assets/labels.txt
  - assets/movenet_thunder.tflite
```

## Step 4: Rebuild the App

After adding the model file, rebuild your Flutter app:
```bash
flutter clean
flutter pub get
flutter build
```

## How It Works

1. When a video is uploaded, frames are extracted from it
2. Each frame is processed with MoveNet Thunder to extract 17 pose keypoints
3. A pose visualization (skeleton overlay) is created from the keypoints
4. The pose visualization image is then fed to the trick classifier
5. The trick classifier analyzes the pose and identifies the trick

## Troubleshooting

- **Model not found error**: Make sure the `movenet_thunder.tflite` file is in the `assets/` folder and `pubspec.yaml` includes it
- **Model loading errors**: Ensure the model file is not corrupted and is the correct TFLite format
- **Performance issues**: MoveNet Thunder is computationally intensive. Consider processing fewer frames or using MoveNet Lightning for faster processing

## Fallback Behavior

If MoveNet Thunder is not available or fails to initialize, the app will automatically fall back to direct image processing without pose estimation. This ensures the app continues to work even without the MoveNet model.
