# WebRTC-iOS
A simple native WebRTC demo iOS app using swift and Socket.IO. This is a modified version of the app https://github.com/stasel/WebRTC-iOS

## Starting NodeJS signaling server
    1. Navigate to the `signaling/NodeJS` folder.
    2. Run `npm install` to install all dependencies.
    3. Run `node app.js` to start the server.

## Run instructions
1. Run the app on two devices with the signaling server running.
2. Make sure both of the devices are connected to the signaling server.
3. On the first device, click on 'Send offer' - this will generate a local offer SDP and send it to the other client using the signaling server.
4. Wait until the second device receives the offer from the first device (you should see that a remote SDP has arrived).
5. Click on 'Send answer' on the second device.
6. when the answer arrives to the first device, both of the devices should be now connected to each other using webRTC, try to talk or click on the 'video' button to start capturing video.
7. To restart the process, kill both apps and repeat steps 1-6.

## References:
* WebRTC website: https://webrtc.org/
* WebRTC source code: https://webrtc.googlesource.com/src
* WebRTC iOS compile guide: https://webrtc.github.io/webrtc-org/native-code/ios/
* appear.in dev blog post: https://github.com/appearin/tech.appear.in/blob/master/source/_posts/Getting-started-with-WebRTC-on-iOS.md (it uses old WebRTC api but still very informative)
* AppRTC: More detailed app to demonstrate WebRTC: https://webrtc.googlesource.com/src/+/refs/heads/master/examples/objc/AppRTCMobile/
* Useful information from pexip: https://pexip.github.io/pexkit-sdk/ios_media
* [Video Chat using WebRTC and Firestore](https://medium.com/@quangtqag/video-chat-using-webrtc-and-firestore-a925de6f89f4) by [Quang](https://github.com/quangtqag)