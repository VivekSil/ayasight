import React, { useRef, useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { Camera } from 'react-native-camera';
import GestureRecognizer from 'react-native-swipe-gestures';
import axios from 'axios';
import express from 'express';
import { launchServer } from './server';

launchServer(); // Start the backend server

const App = () => {
  const cameraRef = useRef(null);
  const [isRecording, setIsRecording] = useState(false);

  const startRecording = async () => {
    if (cameraRef.current && !isRecording) {
      setIsRecording(true);
      const data = await cameraRef.current.recordAsync();
      console.log('Video recorded:', data.uri);
    }
  };

  const stopRecording = async () => {
    if (cameraRef.current && isRecording) {
      cameraRef.current.stopRecording();
      setIsRecording(false);
    }
  };

  const captureImage = async () => {
    if (cameraRef.current) {
      const data = await cameraRef.current.takePictureAsync();
      console.log('Image captured:', data.uri);
      await sendToBackend(data.uri, 'image');
    }
  };

  const sendToBackend = async (fileUri, type) => {
    const formData = new FormData();
    formData.append('file', {
      uri: fileUri,
      name: type === 'video' ? 'video.mp4' : 'image.jpg',
      type: type === 'video' ? 'video/mp4' : 'image/jpeg',
    });
    
    try {
      await axios.post('http://localhost:3000/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
    } catch (error) {
      console.error('Error uploading:', error);
    }
  };

  return (
    <GestureRecognizer
      onSwipeLeft={startRecording}
      onSwipeRight={stopRecording}
      onSwipeDown={(e) => e.numberOfTouches === 2 && captureImage()}
      onSwipeUp={() => isRecording && sendToBackend('video.mp4', 'video')}
      style={styles.container}
    >
      <Camera ref={cameraRef} style={styles.camera} />
    </GestureRecognizer>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1 },
  camera: { flex: 1 },
});

export default App;
