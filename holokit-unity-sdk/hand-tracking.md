# Hand tracking



In this sample, we will guide you to build a minimalist hand tracking project. The fundamental principle of HoloKit hand tracking will also be explained. Please notice that the last stereoscopic rendering sample is the mandatory fundamental part for all HoloKit projects. Therefore, in order to follow this tutorial, you should begin with the result from the last sample.![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=ODE3NjBjY2YxODhkYWM4N2U4N2M0MmRkNDY5ZmNlOTFfekZRQk0wbHp5eDRWaGxzMVNWb2dpWDFDZmUzdUNOZzVfVG9rZW46Ym94Y240MjlCQlJ5aE45NVA2Nmd5S2RyaXVjXzE2NjA4NTc3MDg6MTY2MDg2MTMwOF9WNA)

(The GameObjects in the above image should all be set up property before you continue)One important thing to notice is that HoloKit Hand Tracking only works for iPhones with LiDAR sensor (including iPhone 12 Pro, iPhone 12 Pro Max, iPhone 13 Pro and iPhone 13 Pro Max).

#### The minimalist build

1. In HoloKit SDK folder -> prefabs, you can find a prefab called "**HoloKit Hand Tracker**". Drag this prefab into the scene. Please keep the prefab's default settings and don't change anything.

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=NGQ1NjE3MWQzOTQzODg0ODRlN2U0NTU2Njk4MTZhM2NfU2tndUdXNzNCSmhPZHY5a3NqczI3dWhRTENtRkFEdXhfVG9rZW46Ym94Y24xWEQ3Uk1jUFRMcXRPRmJsaHZoRFBjXzE2NjA4NTc3MDg6MTY2MDg2MTMwOF9WNA)

1. Add `AROcclusionManager` component into your `XROrigin`, disable it and set its attributes as below. The reason for adding this component is to enable the depth map and infer the 3D positions of hand landmarks.

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=NWM2MDViY2NjOWVmYjIzNmI0OTMzZjhmYTg3NzQ3NWJfVzRjbEJtY29XNTAyQjNaYVJpQWNiZXVPeGl2S0wwZnJfVG9rZW46Ym94Y25KQW0xOFoxcjN0d3YzN2RlTlpBYUtQXzE2NjA4NTc3MDg6MTY2MDg2MTMwOF9WNA)

1. Build the project onto your iPhone and you should be able to see the result like this.

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=ZTdhYjJjY2YyNDY5YThlMGE5ZjQwOGQ2MDNhZTA0M2ZfM3J0RDExMUc3QjZoN3VUSXhhZTgyMGFFR2FURm5PZU1fVG9rZW46Ym94Y24yNUhNcE0ycWUyRmM0S2lpelVsM25lXzE2NjA4NTc3MDg6MTY2MDg2MTMwOF9WNA)

Believe it or not, you have finished building a basic hand tracking project!

#### Hand tracking principles

There are several things you need to know to have a basic understanding of our hand tracking functionality:

* For a tracked hand, there are 21 landmarks which indicate 21 hand joints of a human hand. Then names of each landmark are shown in the following image

![](https://holokit.feishu.cn/space/api/box/stream/download/asynccode/?code=MmY0NzdmYWU2YzMzYTgyMDQ5MmMyNDRmYWJiZGYwNDBfS3Vmck5kVURvaFBrOUhrNEV3b1k3bGZtRlV0UkVCUUZfVG9rZW46Ym94Y25LdGlrY2JTMFJZYjZNMXFWcGhaVnNmXzE2NjA4NTc3MDg6MTY2MDg2MTMwOF9WNA)

* Only one hand can be tracked at a time.
  * Of course, it is better to have both hands tracked. But we limit the number to one to save more computational powers. With both hands tracked, your iPhone will become overheated faster.
* The landmarks' rotation data is not tracked, only positions are known.
* Running the hand tracking algorithm is extremely energy consuming, which will cause your iPhone to get overheated very fast. Therefore, it is highly recommended to only turn on the hand tracking when you need it and turn it off when you do not need it.
* In order to keep your hand tracked, you need to put your hand inside the tracking area, which is highly overlapped with the field of view of the HoloKit headset. In other words, you need to let your iPhone's camera see your hand.

#### How to use hand tracking in code

`HoloKitHandTracker` is a singleton class. You can turn hand tracking on and off by

```
HoloKitHandTracker.Instance.Active = true; // or false to turn it off
```

To check if there is a valid hand currently being tracked, you can do

```
// This value is true if there is currently a valid hand being tracked
HoloKitHandTracker.Instance.Valid
```

To get the position of a specific hand landmark, you do

```
// Get the 3D position of the end of the index finger
HoloKitHandTracker.Instance.GetHandJointPosition(HandJoint.Index3)
```

To set the visibility of landmarks, you do

```
HoloKitHandTracker.Instance.Visible = false; // Hide landmarks
```
