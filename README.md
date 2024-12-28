# avplayer_buffer

This project shows IOS AVFoundation AVPlayer with a Customer AVAssetResourceLoader Delegate that can be used to control how much AVPlayer can buffer.

For example, in this demo, we set the buffering to 10 seconds or 1 MByte only.

If the user pauses the video, the buffering will stop, until the user plays again the video.

The app shows the buffered amount in seconds on the mobile screen in real-time for verification.


