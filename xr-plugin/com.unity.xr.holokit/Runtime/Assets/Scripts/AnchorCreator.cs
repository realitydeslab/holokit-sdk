using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARKit;

namespace UnityEngine.XR.HoloKit
{
    public class AnchorCreator : MonoBehaviour
    {

        [SerializeField]
        private GameObject prefab;

        [SerializeField]
        private Transform cameraTransform;

        public AnchorCreator()
        {

        }

        // Start is called before the first frame update
        void Start()
        {

        }

        // Update is called once per frame
        void Update()
        {
            /*
            if (Input.touchCount == 0)
                return;

            var touch = Input.GetTouch(0);
            if (touch.phase != TouchPhase.Began)
                return;

            Vector3 pos = cameraTransform.position + cameraTransform.forward * 1.0f;
            var gameObject = Instantiate(prefab, pos, cameraTransform.rotation);
            ARAnchor anchor;
            anchor = gameObject.GetComponent<ARAnchor>();
            if (anchor == null)
            {
                anchor = gameObject.AddComponent<ARAnchor>();
            }
            */
        }

        public void CreateAnchor(Vector3 position)
        {
            var gameObject = Instantiate(prefab, position, cameraTransform.rotation);
            ARAnchor anchor;
            anchor = gameObject.GetComponent<ARAnchor>();
            if (anchor == null)
            {
                anchor = gameObject.AddComponent<ARAnchor>();
            }
        }
    }
}