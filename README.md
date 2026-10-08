# Attendance Tracker Deployment Script

## About My Project

For my Scripting Summative Lab at ALU, I am working on a Bash script
that automates the setup and management of a Student Attendance Tracker.

My goal is to make the process easier and more reliable instead of
creating project folders and copying files manually every time.

The attendance application is provided in Python. My work focuses on
the shell script that prepares the application, runs it, and manages
the logs it produces.

## What I Am Working On

My project is based on three main tasks:

### 1. Deploying the Application

The deployment process is intended to create a project directory and
copy the required files from the `templates/` folder.

It also needs to handle an existing directory safely, support the
required student roster options, set the correct file permissions,
and allow attendance alert thresholds to be updated.

### 2. Running the Application

The Python application allows an instructor to mark students as
present or absent. It updates the attendance information and produces
the relevant session logs.

The shell script provides a way to run the deployed application.

### 3. Archiving the Logs

After an attendance session, the generated logs need to be saved in
separate archive directories.

The filenames include timestamps so that archived copies can be
identified and kept separately. The script should also handle cases
where a log file was not created.

## Handling Interruptions

Another important part of this assignment is handling Ctrl+C
(`SIGINT`) and Ctrl+Z (`SIGTSTP`) during deployment.

The required behavior is to display a clear message and create a ZIP
archive containing the incomplete project. The script should then
finish the interruption process cleanly.

I will verify this behavior by testing an interrupted deployment and
checking the contents of the resulting archive.

## Technologies I Use

- Bash for automation and signal handling.
- Python 3 for running the attendance application.
- CSV for student attendance records.
- JSON for application configuration.
- Standard Linux utilities for file management and permissions.
- Git and GitHub for version control.

## Project Structure

My repository is organized around the deployment script and the
provided application templates.

```text
deploy_agent_DembaFiorella/
├── deploy_agent.sh
├── README.md
└── templates/
    ├── attendance_checker.py
    ├── assets.csv
    └── config.json
```

The deployment script is expected to create a separate
`attendance_tracker_<name>/` directory containing the application,
its `Helpers/` files, and the `reports/` directory.

The deployed project also contains `archives/` when logs are archived.

## Configuration

The configuration file contains the attendance warning and failure
thresholds, the run mode, and the total number of sessions.

The total session count must match the roster being used:

- The supplied sample roster has four previous sessions, so the
  configured total, including the current session, is five.
- A newly generated roster starts with zero previous sessions, so
  the configured total for its first session is one.

The warning and failure thresholds can be changed through the
deployment process when that option is implemented.

## How to Run

From the repository directory, make the deployment script executable
if necessary:

```bash
chmod +x deploy_agent.sh
```

Start it with:

```bash
./deploy_agent.sh
```

Follow the feature-selection prompts provided by the script.

The exact menu options or command-line flags depend on the
implementation in `deploy_agent.sh`.

## How I Plan to Test My Work

I will check the project against the assignment requirements by:

1. Checking that the required tools are available.
2. Testing deployment into a new directory.
3. Checking what happens when the target directory already exists.
4. Testing both roster creation options.
5. Checking the deployed file permissions and configuration.
6. Running a short attendance-marking session.
7. Checking the log archive directories and timestamped filenames.
8. Testing what happens when a log file is missing.
9. Testing deployment interruption with Ctrl+C and Ctrl+Z.
10. Inspecting the ZIP archive and confirming the cleanup behavior.

I will record actual test results after running these checks rather
than assuming that a feature works simply because it is required.

## What I Have Learned

This project gives me an opportunity to practise shell scripting,
file management, configuration updates, Linux permissions, signal
handling, and Git.

It also helps me understand how automation can reduce repetitive
work and make a setup process more consistent.

## Demonstration Video

I will add my walkthrough video link here after recording and
publishing the demonstration.

Here is my link:

The video will explain my implementation, show a live attendance
session, and demonstrate the deployment interruption behavior.

## Author

**Name:** Demba Fiorella  
**Course:** Scripting Summative Lab  
**Institution:** African Leadership University
