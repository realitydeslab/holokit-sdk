using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class HolokitMRMenuMovementController : MonoBehaviour
{
    [SerializeField] private Transform EyeCenter;
    [SerializeField] private bool isEnterButton;

    [Header("Menu Properties")]
    [SerializeField] private Vector3 offset = new Vector3(0,0,0.5f);
    [SerializeField] private float maxSpeed = .1f;
    [SerializeField] private float maxForce = .1f;
    [SerializeField] private float distanceThreshlod = .1f;

    private Vector3 velocity;
    private Vector3 acceleration;

    private Vector3 newPosition = Vector3.zero;

    void Start()
    {
        if (EyeCenter == null && GameObject.Find("EyeCenterSample") != null)
        {
            EyeCenter = GameObject.Find("EyeCenterSample").transform;
            Debug.Log($"am i find {EyeCenter}");
        }
        else
        {
            Debug.Log("not find EyeCenterSample!!!");
        }

        newPosition = transform.position;
    }

    void FixedUpdate()
    {
        Vector3 targetPosition;
        if (isEnterButton)
        {
            targetPosition = EnterMenuTargetCaculate(EyeCenter, offset);
        }
        else
        {
            targetPosition = BackMenuTargetCaculate(EyeCenter, offset);
        }
        newPosition = AnimatedMove(transform.position, targetPosition, maxSpeed, maxForce, distanceThreshlod);
        transform.position = newPosition;
        transform.LookAt(EyeCenter);
    }

    float map(float x, float minIn, float maxIn, float minOut, float maxOut)
    {
        x = (((x - minIn) / maxIn) * (maxOut - minOut))+ minOut;
        return x;
    }
    Vector3 AnimatedMove(Vector3 position, Vector3 targetPosition, float maxSpeed, float maxForce, float distanceThreshlod)
    {
        float maxSpeedMapDistance = .5f; // get maxspeed when distance reach this value
        Vector3 desired = targetPosition - position;
        float d = desired.magnitude; // equal to distance

        if (d < distanceThreshlod) // do not need to move
        {
            return position;
        }
        else
        {
            if (d < maxSpeedMapDistance)
            {
                float m = map(d, 0, maxSpeedMapDistance, 0, maxSpeed);
                desired = desired.normalized * m;
            }
            else
            {
                desired = desired.normalized * maxSpeed;
            }

            Vector3 steer = desired - velocity;
            if (steer.magnitude > maxForce)
            {
                steer = steer.normalized * maxForce;
            }
            else { }
            acceleration += steer;

            velocity += acceleration;
            if (velocity.magnitude > maxSpeed)
            {
                velocity = velocity.normalized * maxSpeed;
            }
            else { }

            position += velocity;
            acceleration = Vector3.zero;

            return position;
        }
    }
    
    Vector3 EnterMenuTargetCaculate(Transform holoPosition, Vector3 offset)
    {
        Vector3 headsetForwardDirection = EyeCenter.TransformDirection(0, 0, 1); // get headset forward direction
        Vector3 headsetVerticalDirection = EyeCenter.TransformDirection(0, 1, 0); // get headset forward direction
        Vector3 headsetHorizentalDirection = EyeCenter.TransformDirection(1, 0, 0); // get headset forward direction
        Vector3 offsetX = headsetHorizentalDirection * offset.x;
        Vector3 offsetY = headsetVerticalDirection * offset.y;
        Vector3 offsetZ = headsetForwardDirection * offset.z;
        Vector3 sum = offsetX + offsetY + offsetZ;
        return holoPosition.position + sum;
    }

    Vector3 BackMenuTargetCaculate(Transform holoPosition, Vector3 offset)
    {
        Vector3 headsetForwardDirection = EyeCenter.TransformDirection(0, 0, 1); // get headset forward direction
        Vector3 headsetVerticalDirection = EyeCenter.TransformDirection(0, 1, 0); // get headset forward direction
        Vector3 headsetHorizentalDirection = EyeCenter.TransformDirection(1, 0, 0); // get headset forward direction
        Vector3 offsetX = headsetHorizentalDirection * offset.x;
        Vector3 offsetY = new Vector3(0,1,0) * offset.y;
        Vector3 offsetZ = headsetForwardDirection * offset.z;
        Vector3 ooooooo = new Vector3(0 , -.3f, headsetForwardDirection.z*.5f);
        Vector3 sum = offsetX + offsetY + offsetZ;
        return holoPosition.position + ooooooo;
    }
}
