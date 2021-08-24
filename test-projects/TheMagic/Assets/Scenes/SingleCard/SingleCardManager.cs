using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SingleCardManager : MonoBehaviour
{
    [SerializeField] float m_Speed =1f;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.touchCount > 0)
        {
            Touch touch = Input.GetTouch(0); // get first touch since touch count is greater than zero

            if (touch.phase == TouchPhase.Stationary || touch.phase == TouchPhase.Moved)
            {
                // get the touch position from the screen touch to world point
                Vector3 touchedPos = Camera.main.ScreenToWorldPoint(new Vector3(touch.position.x, touch.position.y, 10));
                // lerp and set the position of the current object to that of the touch, but smoothly over time.
                //transform.position = Vector3.Lerp(transform.position, touchedPos, Time.deltaTime);

                transform.Rotate(new Vector3(touch.deltaPosition.y, touch.deltaPosition.x, 0) * m_Speed);
            }
        }
    }


}
