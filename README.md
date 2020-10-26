
![MIT License][license-shield]

<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/othneildrew/Best-README-Template">
    <img src="https://i.imgur.com/UhJQb7x.png" alt="Logo" width="80" height="80">
  </a>
  <p align="center">
	Manage tmux sessions with simple configuration. Lean and  opinionated.
    <br />
  </p>
</p>

![mx.sh](https://imgur.com/r9oTAaa.gif)

###  Why another tmux session manager?
* It has to work out of box without any bloats.
* Because, I didn't want runtime dependency such as Ruby interpreter just to manage my tmux sessions.
* Shell scripting is free and native, lets do more of that.

## Installation

Copy paste this in your terminal

```bash
curl https://raw.githubusercontent.com/RobusGauli/mx.sh/v0.6.1-alpha/install.sh | bash
```
> This will install `mx`  script in your path. Run `mx` to verify the installation.

## Getting Started
Below steps assumes that you have a working knowledge of tmux and you understand the concepts of windows, panes and sessions in tmux. Also, you are able to attach and detach to tmux session. If you think you are rusty around these topics, you could reach out to [man](https://man7.org/linux/man-pages/man1/tmux.1.html) page or this awesome quick tour [blog](https://danielmiessler.com/study/tmux/).

#### 1. Generate configuration template
```bash
mx template --json --session euler
```
#### 2. Start the session 🚀
```bash
mx up
```

#### 3. Attach to the session
```bash
mx attach
```
Congratulations!!

#### To destroy the session
>Note: You need to [detach](https://superuser.com/questions/249659/how-to-detach-a-tmux-session-that-itself-already-in-a-tmux) from the current tmux session before you can destroy.
```bash
mx down --session euler
```

## Learn more

 Below is the configuration template that is created when you run `mx template --session euler`. This will create a **json** configuration file called  `mxconf.json` in your directory where you ran the command . `mx` looks for this file for managing your tmux sesssion.

You could use **yaml** instead of **json** for managing your configuration file by adding `--yaml` flag during template generation.
```sh
mx template --yaml --session novaproject
```
*However, you need to* `pip install pyyaml` *to enable yaml support.*

**NOTE**:  The value of *workdir* is the path that where you ran `mx template`.  For example,
`mx template` command ran on `/home/euler/sessions` path.
 ```yaml
{
  "session": "euler",
  "windows": [
    {
      "name": "w1",
      "panes": [
        {
          "workdir": "/home/euler/sessions",
          "command": "echo \"Hey from pane 1\""
        },
        {
          "workdir": "/home/euler/sessions",
          "command": "echo \"Hi from pane 2\""
        }
      ]
    },
    {
      "name": "w2",
      "panes": [
        {
          "workdir": "/home/euler/sessions",
          "command": "htop"
        },
        {
          "workdir": "/home/euler/sessions",
          "size": 20,
          "command": "python"
        },
        {
          "workdir": "/home/euler/sessions",
          "command": "cal\ndate"
        }
      ]
    }
  ]
}
 ```
The above configuration file defines following resources:
* Tmux sesssion "euler"
* 2 Tmux windows "w1" and "w2"
* 2 Panes in window "w1"
* 3 Panes in window "w2"
* Shell command such as htop, cal, date, python, etc to run on different panes.
* Working directory for each pane.

This will give you a basic overview of how configuration is defined. You could extend this configuration to  have as many number of windows and panes as you wish. You could also run multiple commands by delimiting using `\n`. Typical example would be initiating vpn connection and starting virtual environment for your python development.

Below is the sample configuration using **yaml**
```yaml
session: euler
windows:
- name: w1
  panes:
  - workdir: "/home/euler/sessions"
    command: echo "Hey from pane 1"
  - workdir: "/home/euler/sessions"
    command: echo "Hi from pane 2"
- name: w2
  panes:
  - workdir: "/home/euler/sessions"
    command: htop
  - workdir: "/home/euler/sessions"
    size: 20
    command: python
  - workdir: "/home/euler/sessions"
    command: |-
      cal
      date
```

And, below is my typical configuration that I personally use in managing one of my project.

```yaml
session: node
windows:
  - name: functions
    panes:
      - workdir: ~/work/sessions/node/function/
        command: nvim # Start neovim session
      - workdir: ~/work/sessions/node/function/
        command: npm version
  - name: api
    panes:
      - workdir: ~/work/sessions/node/node_backend/
        command: nvim
      - workdir: ~/work/sessions/node/node_backend/
        size: 20
        command: |-
          # connect to vpn
          nordvpn connect de507
          # Activate python environment
          source venv/bin/activate
          # Source environment variables
          source env.stage.sh
          # Run the app
          python app/run.py
      - workdir: ~/work/sessions/node/node_backend/
        command: |-
          # Run postman
          postman
  - name: database
    panes:
      - workdir: ~/work/sessions/node/node_backend
        command: |-
          # Connect to vpn
          nordvpn connect de507
          # SSH into bastion hosts
          ssh engineer@ec1*.3*.342.us-west-2.compute.amazonaws.com
          # Run alias command
          alias
      - workdir: ~/work/sessions/node/node_backend/
        size: 20
        command: |-
          # Open sql client
          beekeeper-studio
      - workdir: ~/work/sessions/node/node_backend/
        command: |-
	  # Open firefox browser with my jira tickets
          firefox https://node.atlassian.net/jira/
```
####  Starting  session
After you have written/edited configuration file according to your requirement, you could start the session simply by running
```bash
mx up
```
 This command looks for `mxconf.yaml` or `mxconf.json` file in the current directory and provisions a new session for you. This command will start the session but won't automatically attach to it.  If you want to attach to session  after you start the session, you could run
 ```bash
 mx up --attach
 ```
If you want to use different session name overriding name of session that is defined in your configuration, you could run
```bash
mx up --session bigbang
```

#### List sessions
You could verify by running `mx list` command that will list all active tmux sessions. Below is the output that you can expect from running `mx list` command.

```
1 => mxsession: 2 windows (created Mon Oct 26 09:20:10 2020) [190x46]
2 => node: 2 windows (created Mon Oct 26 09:57:06 2020) [80x24]
```
You can see that there are 2 active tmux sessions running named "mxsession" and "node". If you notice carefully, they are indexed using number 1 and 2 respectively. Number 1 is assigned to session named "mxsession" and number 2 is assigned to "node" session.

#### Attaching to session
Now to attach to one of the running session(s), you could simple run
```sh
mx attach --session mxsession
```
The above command attaches to session named "mxsession"

You could also use index to attach to "mxsession" session by running
```bash
mx attach --index 1
```
If you think this is just too much typing, run `mx attach` and it will simply attach to recently created session.

#### Destroying session

**NOTE**: In order to destroy the session, you need to detach from the running session.

To destroy the running session, you could run
```bash
mx down --session euler
```
The above command will destroy the session named "euler". If you want to destroy all the active sessions, you could simply run
```bash
mx down --all
```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE` for more information.




[license-shield]: https://img.shields.io/github/license/othneildrew/Best-README-Template.svg?style=flat-square
