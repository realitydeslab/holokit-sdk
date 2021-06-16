# HoloKitSDK

## A step by step guide on how to turn your existing Unity project into a HoloKit App.

Please note that this method only works on iOS.

### Step 0: Cloning HoloKit SDK project to your computer

Open the terminal, go to an appropriate file path (the place you want to put the project) and enter the following instruction

```
git clone -b yuchen https://github.com/holoi/HoloKitSDK.git
```
(Notice that we are cloning branch "yuchen")

If everything goes well, we should see the result like this.

<a href="https://ibb.co/BGLsjjy"><img src="https://i.ibb.co/HC7gYYt/Screen-Shot-2021-06-15-at-11-30-52-AM.png" alt="Screen-Shot-2021-06-15-at-11-30-52-AM" border="0"></a><br /><a target='_blank' href='https://imgbb.com/'></a><br />


### Step 1: Pasting HoloKit SDK into your Unity project folder

In HoloKit SDK project folder, copy the folder "com.unity.xr.holokit",

<a href="https://ibb.co/Jz5Q5bz"><img src="https://i.ibb.co/HrndnMr/Screen-Shot-2021-06-15-at-11-41-24-AM.png" alt="Screen-Shot-2021-06-15-at-11-41-24-AM" border="0"></a><br /><a target='_blank' href='https://imgbb.com/'></a><br />

and paste it into your Unity project package folder.

<a href="https://ibb.co/h888Mqf"><img src="https://i.ibb.co/ysssR3S/Screen-Shot-2021-06-15-at-11-43-39-AM.png" alt="Screen-Shot-2021-06-15-at-11-43-39-AM" border="0"></a><br /><a target='_blank' href='https://imgbb.com/'></a><br />

Open your Unity project, and you should now see HoloKit SDK successfully installed.

<a href="https://ibb.co/b7CDQCW"><img src="https://i.ibb.co/N7JbtJV/Screen-Shot-2021-06-15-at-11-49-22-AM.png" alt="Screen-Shot-2021-06-15-at-11-49-22-AM" border="0"></a>

### Step 2: Setting up HoloKit XR scene

In order to run a XR scene, we need to drag some necessary game objects into the scene. Fortunately, all necessary game objects are prepared for you as prefabs in HoloKit XR Plugin folder.

<a href="https://ibb.co/PTDsr3n"><img src="https://i.ibb.co/VHw0LrZ/Screen-Shot-2021-06-15-at-11-54-40-AM.png" alt="Screen-Shot-2021-06-15-at-11-54-40-AM" border="0"></a><br /><a target='_blank' href='https://imgbb.com/'></a><br />

All you need to do is deleting the existing main camera in your scene and dragging the prefab "HoloKit" into your scene.

### Step 2.5: HoloKit settings (optional)

In "HoloKit" prefab, there are some settings in the inspector panel. For example, your can untick "Hand Tracking Enabled" option to turn off hand tracking in order to improve efficiency (this is highly recommanded if you do not need it).

<a href="https://ibb.co/zxrnWCQ"><img src="https://i.ibb.co/3d7r5V4/Screen-Shot-2021-06-15-at-12-02-27-PM.png" alt="Screen-Shot-2021-06-15-at-12-02-27-PM" border="0"></a><br /><a target='_blank' href='https://imgbb.com/'></a><br />

### Step 3: Configuring Unity project settings

You still need to figure out some settings.

* In Project Settings -> XR Plugin-in Management, tick both ARKit and HoloKit in iOS panel.

<a href="https://ibb.co/vhB9nHw"><img src="https://i.ibb.co/C6tLGz1/Screen-Shot-2021-06-15-at-12-08-11-PM.png" alt="Screen-Shot-2021-06-15-at-12-08-11-PM" border="0"></a>

* In Project Settings -> Player -> Other Settings, fill in some words in "Camera Usage Description" and set "Target minimum iOS Version" to 14.0.

<a href="https://ibb.co/BZrX5qs"><img src="https://i.ibb.co/tsx7T8C/Screen-Shot-2021-06-15-at-12-10-56-PM.png" alt="Screen-Shot-2021-06-15-at-12-10-56-PM" border="0"></a>

* In Project Settings -> Player -> Resolution and Presentation, set "Default Orientation" to "Landscape Left".

<a href="https://ibb.co/tc03kNH"><img src="https://i.ibb.co/ft3QBKX/Screen-Shot-2021-06-15-at-12-16-37-PM.png" alt="Screen-Shot-2021-06-15-at-12-16-37-PM" border="0"></a>

* The last step is to set up the URP asset, since HoloKit SDK only works on URP. First, create a new URP asset.

<a href="https://ibb.co/RTYRBv0"><img src="https://i.ibb.co/PGFq9mh/Screen-Shot-2021-06-16-at-4-58-27-PM.png" alt="Screen-Shot-2021-06-16-at-4-58-27-PM" border="0"></a><br /><a target='_blank' href='https://nonprofitlight.com/me/calais/washington-county-emergency-medical-services-authority'></a><br />

After you create the URP asset, there will be a corresponding renderer data asset. Select it and add "AR Background Renderer Feature" in the inspector.

<a href="https://ibb.co/17Jc96V"><img src="https://i.ibb.co/LYhKC5w/Screen-Shot-2021-06-16-at-4-59-05-PM.png" alt="Screen-Shot-2021-06-16-at-4-59-05-PM" border="0"></a><br /><a target='_blank' href='https://nonprofitlight.com/me/calais/washington-county-emergency-medical-services-authority'></a><br />

Go to Project Settings -> Graphics, and assign "Scriptable Render Pipeline Settings" with your newly created URP asset.

<a href="https://ibb.co/68p6V1B"><img src="https://i.ibb.co/r3LnTcs/Screen-Shot-2021-06-16-at-5-09-09-PM.png" alt="Screen-Shot-2021-06-16-at-5-09-09-PM" border="0"></a><br /><a target='_blank' href='https://nonprofitlight.com/me/calais/washington-county-emergency-medical-services-authority'></a><br />

After changing the rendering pipeline to URP, some of your previous materials will possibly become invalid (they are purple now). Don't worry, that is because those objects are using standard render pipeline materials. Just give them some URP materials and everything will be fine.

Now, theoretically, you can build your HoloKit App and run it on your iPhone!

### FAQ

To be added...
