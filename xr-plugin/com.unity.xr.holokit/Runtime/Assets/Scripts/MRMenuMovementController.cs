using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.HoloKit;

public class MRMenuMovementController : MonoBehaviour
{
    [SerializeField] private Transform EyeCenter;
    [SerializeField] private bool m_isFacingButton;

    [Header("Menu Properties")]
    [SerializeField] private Vector3 offset = new Vector3(0, 0, 0.5f);
    [SerializeField] private float maxSpeed = .1f;
    [SerializeField] private float maxForce = .1f;
    [SerializeField] private float distanceThreshlod = .1f;

    private Vector3 velocity;
    private Vector3 acceleration;

    private Vector3 newPosition = Vector3.zero;

    void Start()
    {
        newPosition = transform.position;
    }

    void FixedUpdate()
    {
        // do not work propertly, ask yc later
        //Camera cam = Camera.main;
        //Vector3 offset = HoloKitSettings.CameraToCenterEyeOffset;

        //offset = cam.transform.TransformVector(offset);
        //var EyePos = cam.transform.position + offset;
        //EyeCenter.position = EyePos;
        //Debug.Log("EyeCenterPos:" + EyePos);

        Vector3 targetPosition;
        if (m_isFacingButton)
        {
            targetPosition = FacingMenuTargetCaculate(EyeCenter, offset);
        }
        else
        {
            targetPosition = FacingDownMenuTargetCaculate(EyeCenter, offset);
        }

        transform.position += (targetPosition - transform.position) * Time.deltaTime * 5;
        transform.LookAt(EyeCenter);

        // animate mode 2:
        //newPosition = AnimatedMove(transform.position, targetPosition, maxSpeed, maxForce, distanceThreshlod);
        //transform.position = newPosition;

    }

    float map(float x, float minIn, float maxIn, float minOut, float maxOut)
    {
        x = (((x - minIn) / maxIn) * (maxOut - minOut)) + minOut;
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

    Vector3 FacingMenuTargetCaculate(Transform TargetPosition, Vector3 offset)
    {
        Vector3 headsetForwardDirection = EyeCenter.TransformDirection(0, 0, 1); // get headset forward direction
        Vector3 headsetVerticalDirection = EyeCenter.TransformDirection(0, 1, 0); // get headset forward direction
        Vector3 headsetHorizentalDirection = EyeCenter.TransformDirection(1, 0, 0); // get headset forward direction
        Vector3 offsetX = headsetHorizentalDirection * offset.x;
        Vector3 offsetY = headsetVerticalDirection * offset.y;
        Vector3 offsetZ = headsetForwardDirection * offset.z;
        Vector3 sum = offsetX + offsetY + offsetZ;
        return TargetPosition.position + sum;
    }

    Vector3 FacingDownMenuTargetCaculate(Transform TargetPosition, Vector3 offset)
    {
        Vector3 headsetForwardDirection = EyeCenter.TransformDirection(0, 0, 1); // get headset forward direction
        Vector3 headsetVerticalDirection = EyeCenter.TransformDirection(0, 1, 0); // get headset forward direction
        Vector3 headsetHorizentalDirection = EyeCenter.TransformDirection(1, 0, 0); // get headset forward direction
        Vector3 offsetX = headsetHorizentalDirection * offset.x;
        Vector3 offsetY = new Vector3(0, 1, 0) * offset.y;
        Vector3 offsetZ = headsetForwardDirection * offset.z;
        Vector3 ooooooo = new Vector3(0, -.3f, headsetForwardDirection.z * .5f);
        Vector3 sum = offsetX + offsetY + offsetZ;
        return TargetPosition.position + ooooooo;
    }
}
