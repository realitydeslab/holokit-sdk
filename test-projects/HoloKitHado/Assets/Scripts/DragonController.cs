using UnityEngine;
using UnityEngine.InputSystem;
using MLAPI;


public class DragonController : NetworkBehaviour
{
    private Vector3 m_position;
    private Vector3 m_rotation;
    [SerializeField]
    private float m_rotateSpeed = 1f;
    [SerializeField]
    private float m_walkSpeed = 1f;

    Animator m_animator;

    private void Awake()
    {
        if (IsOwner)
        {
            m_animator = GetComponent<Animator>();
        }
    }

    private void Update()
    {
        if (!IsOwner) { return; }

        Movement();
    }


    void Movement()
    {
        m_rotation = transform.rotation.eulerAngles;
        m_position = transform.position;

        var gamepad = Gamepad.current;
        if (gamepad == null)
            return; // No gamepad connected.

        Vector2 move1 = gamepad.leftStick.ReadValue();
        Vector2 move2 = gamepad.rightStick.ReadValue();


        // 'Move' code here
        transform.rotation *= Quaternion.Euler(new Vector3(0, move2.x * Time.deltaTime * m_rotateSpeed, 0));

        transform.position += transform.forward * move1.y * Time.deltaTime * m_walkSpeed + transform.right * move1.x * Time.deltaTime * m_walkSpeed;

        if (gamepad.leftStick.IsPressed())
        {
            m_animator.SetBool("isMoving", true);
            m_animator.SetFloat("F", move1.y);
            m_animator.SetFloat("R", move1.x);
        }
        else
        {
            m_animator.SetBool("isMoving", false);
        }


        if (gamepad.rightStick.IsPressed())
        {

        }

        if (gamepad.yButton.isPressed)
        {

        }
        if (gamepad.xButton.isPressed)
        {

        }

        if (gamepad.aButton.isPressed)
        {
            m_animator.SetTrigger("Projectile Attack");

        }
        if (gamepad.bButton.isPressed)
        {

        }
    }

    private void OnCollisionEnter(Collision collision)
    {
        if (!IsServer) { return; }
    }
}
