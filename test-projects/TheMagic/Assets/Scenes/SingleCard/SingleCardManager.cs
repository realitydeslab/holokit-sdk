/// this is a card-touching controller
/// 
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SingleCardManager : MonoBehaviour
{
    [SerializeField] float m_Speed = 1f;
    [SerializeField] Vector3 testRotate;
    // Start is called before the first frame update
    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {
#if (UNITY_EDITOR)
        // do your code
        transform.Rotate(testRotate);
#endif

        if (Input.touchCount > 0)
        {
            Touch touch = Input.GetTouch(0); // get first touch since touch count is greater than zero

            if (touch.phase == TouchPhase.Stationary || touch.phase == TouchPhase.Moved)
            {
                // get the touch position from the screen touch to world point
                Vector3 touchedPos = Camera.main.ScreenToWorldPoint(new Vector3(touch.position.x, touch.position.y, 10));
                // lerp and set the position of the current object to that of the touch, but smoothly over time.
                //transform.position = Vector3.Lerp(transform.position, touchedPos, Time.deltaTime);
                var dx = touch.deltaPosition.x;
                var dy = touch.deltaPosition.y;

                transform.Rotate(new Vector3(-dy, -dx, 0) * m_Speed);
                Debug.Log(touchedPos);
            }
        }
        else
        {
            Debug.Log("no touch found");
        }
    }


}
