using System.Collections;
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class PlayerMovement : MonoBehaviour
{
    [Header("Misc")]
    public Transform playerCam;
    public PlayerCamScript camScript;
    public Camera cam;
    public Transform orientation;
    public Rigidbody rb;
    public bool canMove = true;

    [Header("Movement")]
    private float moveSpeed;
    public float walkSpeed;
    public float slideSpeed;
    public float wallrunSpeed;
    public float swingSpeed;

    private float desiredMoveSpeed;
    private float lastDesiredMoveSpeed;

    public float groundDrag;

    [Header("Jumping")]
    public float jumpForce;
    public float jumpCooldown;
    public float airMultiplier;
    bool readyToJump;

    [Header("Ground Check")]
    public float playerHeight;
    public LayerMask whatIsGround;
    public bool grounded;

    [Header("Crouching")]
    public float crouchSpeed;
    public float crouchYScale;
    private float startYScale;

    [Header("Sliding")]
    public bool canSlide;
    public float maxSlideTime;
    public float slideForce;
    private float slideTimer;

    public float slideYScale;
    private bool sliding;

    [Header("Slope Handling")]
    public float maxSlopeAngle;
    private RaycastHit slopeHit;
    private bool exitingSlope;

    [Header("WallRunning")]
    public LayerMask whatIsWall;
    private bool wallRunning;
    private bool exitingWall;
    public float exitWallTime;
    private float exitWallTimer;

    public float wallRunForce;
    public float wallJumpUpForce;
    public float wallJumpSideForce;
    public float maxWallRunTime;
    private float wallRunTimer;

    public float wallCheckDistance;
    public float minJumpHeight;
    private RaycastHit leftWallHit;
    private RaycastHit rightWallHit;
    private bool wallLeft;
    private bool wallRight;

    [Header("SFX")]
    public AudioClip[] footsteps;
    public AudioClip jumpsfx;
    public AudioClip[] landsfx;
    public AudioSource airsfx;
    public float footstepRate;
    private float footTime;

    [Header("Keybinds")]
    public KeyCode jumpKey = KeyCode.Space;
    public KeyCode dashKey = KeyCode.LeftShift;
    public KeyCode crouchKey = KeyCode.C;
    public KeyCode slideKey = KeyCode.LeftControl;

    //Input
    public float x, y;

    //Dash
    private bool dashing;
    public bool swinging;

    Vector3 moveDirection;

    private Vector3 spawnPos;

    //if (!crouching && !wallRunning && Input.GetKeyDown(KeyCode.LeftShift))
    //    {
    //        Dash();
    //    }

    public MovementState state;
    public enum MovementState
    {
        walking,
        wallrunning,
        swinging,
        crouching,
        sliding,
        air
    }
    void Awake()
    {
        rb = GetComponent<Rigidbody>();
        spawnPos = rb.position;
    }

    private void Start()
    {
        footTime = footstepRate;

        rb.freezeRotation = true;

        readyToJump = true;

        startYScale = transform.localScale.y;

        canSlide = GameManager.instance.SettingsObj.SlideCheat;
    }

    private void Update()
    {
        // ground check
        bool justGrounded = grounded;

        grounded = Physics.Raycast(transform.position, Vector3.down, playerHeight * 0.5f + 0.2f, whatIsGround);

        if (!justGrounded && grounded)
        {
            SFXManager.instance.PlayRandomSFXClip(landsfx, transform, 0.2f, true);
        }

        MyInput();
        SpeedControl();
        StateHandler();
        checkWallRun();

        // handle drag
        if (grounded)
            rb.linearDamping = groundDrag;
        else
            rb.linearDamping = 0;

        PreventOOB();
    }

    private void FixedUpdate()
    {
        MovePlayer();
    }

    private void StateHandler()
    {
        // Mode - Wallrunning
        if (wallRunning)
        {
            state = MovementState.wallrunning;
            desiredMoveSpeed = wallrunSpeed;
        }

        // Mode - Sliding
        if (sliding)
        {
            state = MovementState.sliding;

            if (OnSlope() && rb.linearVelocity.y < 0.1f)
            {
                desiredMoveSpeed = slideSpeed;
            }

            else
            {
                desiredMoveSpeed = walkSpeed;
            }
        }

        // Mode - Swinging
        else if (swinging)
        {
            state = MovementState.swinging;
            moveSpeed = swingSpeed;
        }

        // Mode - Crouching
        else if (Input.GetKey(crouchKey))
        {
            state = MovementState.crouching;
            moveSpeed = crouchSpeed;
        }

        // Mode - Walking
        else if (grounded)
        {
            state = MovementState.walking;
            desiredMoveSpeed = walkSpeed;

        }

        // Mode - Air
        else
        {
            state = MovementState.air;
            airsfx.enabled = true;
        }

        if (state != MovementState.air)
        {
            airsfx.enabled = false;
        }

        if (MathF.Abs(desiredMoveSpeed - lastDesiredMoveSpeed) > 4f && moveSpeed != 0)
        {
            StopAllCoroutines();
            StartCoroutine(SmoothlyLerpMoveSpeed());
        }
        else
        {
            moveSpeed = desiredMoveSpeed;
        }

        lastDesiredMoveSpeed = desiredMoveSpeed;

    }

    private IEnumerator SmoothlyLerpMoveSpeed()
    {
        float time = 0;
        float difference = Mathf.Abs(desiredMoveSpeed - moveSpeed);
        float startValue = moveSpeed;

        while (time < difference)
        {
            moveSpeed = Mathf.Lerp(startValue, desiredMoveSpeed, time / difference * 2);
            time += Time.deltaTime;
            yield return null;
        }

        moveSpeed = desiredMoveSpeed;
    }

    private void MyInput()
    {
        if (canMove)
        {
            x = Input.GetAxisRaw("Horizontal");
            y = Input.GetAxisRaw("Vertical");


            if (Input.GetKey(jumpKey) && readyToJump && grounded)
            {
                readyToJump = false;

                Jump();

                Invoke(nameof(ResetJump), jumpCooldown);
            }

            if (Input.GetKeyDown(slideKey) && (x != 0 || y != 0) && canSlide)
            {
                StartSlide();
            }
            // start crouch
            if (Input.GetKeyDown(crouchKey))
            {
                transform.localScale = new Vector3(transform.localScale.x, crouchYScale, transform.localScale.z);
                rb.AddForce(Vector3.down * 5f, ForceMode.Impulse);
            }
        }
        else
        {
            x = 0;
            y = 0;
        }

        // stop crouch
        if (Input.GetKeyUp(slideKey) && sliding == true)
        {
            StopSlide();
        }
        if (Input.GetKeyUp(crouchKey))
        {
            transform.localScale = new Vector3(transform.localScale.x, startYScale, transform.localScale.z);
        }
    }

    private void MovePlayer()
    {
        if (swinging) return;
        // calculate movement direction
        moveDirection = orientation.forward * y + orientation.right * x;

        if (wallRunning)
        {
            WallRunningMovement();
        }

        // on slope
        if (OnSlope() && !exitingSlope)
        {
            rb.AddForce(GetSlopeMoveDirection(moveDirection) * moveSpeed * 20f, ForceMode.Force);

            if (rb.linearVelocity.y > 0)
                rb.AddForce(Vector3.down * 80f, ForceMode.Force);
        }

        // on ground
        else if (grounded)
            rb.AddForce(moveDirection.normalized * moveSpeed * 10f, ForceMode.Force);

        // in air
        else if (!grounded)
            rb.AddForce(moveDirection.normalized * moveSpeed * 10f * airMultiplier, ForceMode.Force);

        if (footTime < footstepRate && (y != 0 || x != 0))
        {
            footTime += Time.deltaTime;
        }
        else if ((y != 0 || x != 0) && state == MovementState.walking)
        {
            footTime = 0f;
            SFXManager.instance.PlayRandomSFXClip(footsteps, transform, 0.2f, true);
        }
        else if (state == MovementState.walking)
        {
            footTime = footstepRate;
        }

        // turn gravity off while on slope
        rb.useGravity = !OnSlope();

        if (sliding)
        {
            SlidingMovement();
        }
    }

    private void PreventOOB()
    {
        float yPos = rb.position.y;
        if (yPos < -50)
        {
            rb.position = spawnPos;
        }
    }

    private void SpeedControl()
    {
        // limiting speed on slope
        if (OnSlope() && !exitingSlope)
        {
            if (rb.linearVelocity.magnitude > moveSpeed)
                rb.linearVelocity = rb.linearVelocity.normalized * moveSpeed;
        }

        // limiting speed on ground or in air
        else
        {
            Vector3 flatVel = new Vector3(rb.linearVelocity.x, 0f, rb.linearVelocity.z);

            // limit velocity if needed
            if (flatVel.magnitude > moveSpeed)
            {
                Vector3 limitedVel = flatVel.normalized * moveSpeed;
                rb.linearVelocity = new Vector3(limitedVel.x, rb.linearVelocity.y, limitedVel.z);
            }
        }
    }

    private void Jump()
    {
        exitingSlope = true;

        // reset y velocity
        rb.linearVelocity = new Vector3(rb.linearVelocity.x, 0f, rb.linearVelocity.z);

        rb.AddForce(transform.up * jumpForce, ForceMode.Impulse);

        SFXManager.instance.PlaySFXClip(jumpsfx, transform, 0.25f, true);

    }
    private void ResetJump()
    {
        readyToJump = true;

        exitingSlope = false;
    }

    private bool OnSlope()
    {
        if (Physics.Raycast(transform.position, Vector3.down, out slopeHit, playerHeight * 0.5f + 0.3f))
        {
            float angle = Vector3.Angle(Vector3.up, slopeHit.normal);
            return angle < maxSlopeAngle && angle != 0;
        }

        return false;
    }

    private Vector3 GetSlopeMoveDirection(Vector3 direction)
    {
        return Vector3.ProjectOnPlane(direction, slopeHit.normal).normalized;
    }

    private void StartSlide()
    {
        sliding = true;
        transform.localScale = new Vector3(transform.localScale.x, slideYScale, transform.localScale.z);
        rb.AddForce(Vector3.down * 5f, ForceMode.Impulse);

        slideTimer = maxSlideTime;
    }

    private void SlidingMovement()
    {
        Vector3 inputDirection = orientation.forward * y + orientation.right * x;

        //normal
        if (!OnSlope() || rb.linearVelocity.y > -0.1f)
        {
            rb.AddForce(inputDirection.normalized * slideForce, ForceMode.Force);

            slideTimer -= Time.deltaTime;
        }

        //slope
        else
        {
            rb.AddForce(GetSlopeMoveDirection(inputDirection) * slideForce, ForceMode.Force);
        }

        if (slideTimer <= 0)
        {
            StopSlide();
        }
    }

    private void StopSlide()
    {
        sliding = false;

        transform.localScale = new Vector3(transform.localScale.x, startYScale, transform.localScale.z);
    }

    private bool AboveGround()
    {
        return !Physics.Raycast(transform.position, Vector3.down, minJumpHeight, whatIsGround);
    }

    private void checkWallRun()
    {

        wallRight = Physics.Raycast(transform.position, orientation.right, out rightWallHit, wallCheckDistance, whatIsWall);
        wallLeft = Physics.Raycast(transform.position, -orientation.right, out leftWallHit, wallCheckDistance, whatIsWall);

        if ((wallLeft || wallRight) && y > 0 && AboveGround() && !exitingWall)
        {
            if (!wallRunning)
                StartWallRun();
            if (wallRunTimer > 0)
            {
                wallRunTimer -= Time.deltaTime;
            }
            if (wallRunTimer <= 0 && wallRunning)
            {
                exitingWall = true;
                exitWallTimer = exitWallTime;
            }

            if (Input.GetKeyDown(jumpKey))
                WallJump();
        }

        else if (exitingWall)
        {
            if (wallRunning)
            {
                StopWallRun();
            }
            if (exitWallTimer > 0)
            {
                exitWallTimer -= Time.deltaTime;
            }
            if (exitWallTimer <= 0)
            {
                exitingWall = false;
            }
        }

        else
        {
            if (wallRunning)
            {
                StopWallRun();
            }
        }
    }

    private void StartWallRun()
    {
        wallRunning = true;

        wallRunTimer = maxWallRunTime;

        //camScript.DoFOV(85f);
        //if (wallLeft) camScript.DoTilt(-5f);
        //if (wallRight) camScript.DoTilt(5f);
    }

    private void WallRunningMovement()
    {
        rb.useGravity = false;
        rb.linearVelocity = new Vector3(rb.linearVelocity.x, 0f, rb.linearVelocity.z);

        Vector3 wallNormal = wallRight ? rightWallHit.normal : leftWallHit.normal;
        Vector3 wallForward = Vector3.Cross(wallNormal, transform.up);

        if ((orientation.forward - wallForward).magnitude > (orientation.forward - -wallForward).magnitude)
        {
            wallForward = -wallForward;
        }

        rb.AddForce(wallForward * wallRunForce, ForceMode.Force);

        if (!(wallLeft && x > 0) && !(wallRight && x < 0))
            rb.AddForce(-wallNormal * 100, ForceMode.Force);
    }

    private void StopWallRun()
    {
        rb.useGravity = true;
        wallRunning = false;

        //camScript.DoFOV(70f);
        //camScript.DoTilt(0f);
    }

    private void WallJump()
    {
        exitingWall = true;
        exitWallTimer = exitWallTime;

        Vector3 wallNormal = wallRight ? rightWallHit.normal : leftWallHit.normal;

        Vector3 forceToApply = transform.up * wallJumpUpForce + wallNormal * wallJumpSideForce;

        rb.linearVelocity = new Vector3(rb.linearVelocity.x, 0f, rb.linearVelocity.z);
        rb.AddForce(forceToApply, ForceMode.Impulse);
        SFXManager.instance.PlaySFXClip(jumpsfx, transform, 0.25f, true);
    }


    /*private void Dash()
    {
        if (dashing == true) return;
        dashing = true;
        rb.AddForce(playerCam.forward * 40, ForceMode.VelocityChange);
        Invoke(nameof(resetDash), 2);
    }

    private void resetDash()
    {
        dashing = false;
    }*/

}
