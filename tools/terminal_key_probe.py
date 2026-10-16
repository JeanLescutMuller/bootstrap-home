#!/usr/bin/env python3
"""One-machine Enter/Shift+Enter probe for bare, tmux, Claude, and Codex.

Run by hand, directly in an interactive terminal:  python3 ~/dev/my-setup/tools/terminal_key_probe.py
Why and what the results mean: doc/shift_enter_over_ssh.md
"""
import argparse, fcntl, os, pty, re, select, shlex, signal, struct, subprocess, sys, termios, time, tty
from pathlib import Path

# Restore every terminal mode that tmux/Claude may leave enabled when the
# disposable PTY job is force-stopped: keyboard stack, mouse protocols, focus
# events, bracketed paste, alternate screen, cursor visibility, and styling.
RESET=(
    b"\x1b[<u"
    b"\x1b[>4;0m"  # disable xterm modifyOtherKeys
    b"\x1b[?1000l\x1b[?1002l\x1b[?1003l"
    b"\x1b[?1005l\x1b[?1006l\x1b[?1015l\x1b[?1016l"
    b"\x1b[?1004l\x1b[?2004l"
    b"\x1b[?1049l\x1b[?25h\x1b[0m"
)
SOCK="__key_probe__"
def machine_name() -> str:
    """This machine's name: skill "machine-name" (copy it identically)."""
    name = (os.environ.get("JR_MACHINE_NAME") or (
        subprocess.run(["scutil", "--get", "HostName"], capture_output=True, text=True).stdout
        if sys.platform == "darwin" else Path("/etc/hostname").read_text())).strip().split(".")[0]
    if not re.fullmatch(r"[A-Za-z0-9-]+", name):
        raise RuntimeError("no machine name: macOS sudo scutil --set HostName <name>; Linux sudo hostnamectl set-hostname <name>")
    return name


def out(x): os.write(1, x.encode() if isinstance(x,str) else x)
def hx(x): return " ".join(f"{b:02x}" for b in x) if x else "<timeout>"
def drain(fd):
    while select.select([fd],[],[],0)[0]: os.read(fd,4096)
def event(fd):
    if not select.select([fd],[],[],20)[0]: return b""
    data=os.read(fd,256)
    while select.select([fd],[],[],.12)[0]: data+=os.read(fd,256)
    return data
def spawn(cmd, ttyfd):
    pid,master=pty.fork()
    if pid==0: os.execvp(cmd[0],cmd)
    try: size=fcntl.ioctl(ttyfd,termios.TIOCGWINSZ,b"\0"*8)
    except OSError: size=struct.pack("HHHH",24,80,0,0)
    fcntl.ioctl(master,termios.TIOCSWINSZ,size); os.set_blocking(master,False)
    return pid,master
def warm(pid,master,ttyfd,seconds):
    started=time.monotonic(); minimum=started+seconds; hard_end=started+max(20,seconds+15); last_output=started
    while time.monotonic()<hard_end:
        if time.monotonic()>=minimum and time.monotonic()-last_output>=.8: return
        if os.waitpid(pid,os.WNOHANG)[0]: raise RuntimeError("command exited during startup")
        ready,_,_=select.select([master,ttyfd],[],[],.05)
        if master in ready:
            try:
                data=os.read(master,65536)
                if data: out(data); last_output=time.monotonic()
            except (BlockingIOError,OSError): pass
        if ttyfd in ready:
            data=os.read(ttyfd,4096)
            if data:
                try: os.write(master,data)  # terminal query response
                except (BlockingIOError,OSError): pass
def stop_child(pid):
    """Force-stop the disposable PTY job; never perform a blocking wait."""
    try: os.killpg(pid,signal.SIGKILL)
    except ProcessLookupError: pass
    try: os.kill(pid,signal.SIGKILL)
    except ProcessLookupError: pass
    deadline=time.monotonic()+.5
    while time.monotonic()<deadline:
        try:
            if os.waitpid(pid,os.WNOHANG)[0]: return
        except ChildProcessError: return
        time.sleep(.05)
def capture(i,total,name,cmd,ttyfd,wait):
    out(f"\x1b[2J\x1b[HStarting {i}/{total}: {name}\r\nCommand: {shlex.join(cmd)}\r\n")
    pid,master=spawn(cmd,ttyfd); status="ok"; enter=shift=b""
    try:
        warm(pid,master,ttyfd,wait); drain(ttyfd)
        out(f"\r\n\x1b[7m KEY PROBE \x1b[0m {name}\r\nPress Enter: ")
        enter=event(ttyfd); out(f" [{hx(enter)}]\r\nPress Shift+Enter: ")
        shift=event(ttyfd); out(f" [{hx(shift)}]\r\n")
    except Exception as e: status=str(e); out(f"\r\nERROR: {e}\r\n")
    finally:
        stop_child(pid)
        os.close(master); out(RESET); time.sleep(.1); drain(ttyfd)
    return enter,shift,status
def capture_direct(i,total,name,ttyfd):
    out(f"\x1b[2J\x1b[HStarting {i}/{total}: {name}\r\n")
    drain(ttyfd); out(f"\r\n\x1b[7m KEY PROBE \x1b[0m {name}\r\nPress Enter: ")
    enter=event(ttyfd); out(f" [{hx(enter)}]\r\nPress Shift+Enter: ")
    shift=event(ttyfd); out(f" [{hx(shift)}]\r\n"); return enter,shift,"ok"
def main():
    p=argparse.ArgumentParser(description="Print an Enter/Shift+Enter key-byte table for this machine")
    p.add_argument("--claude",default="claude"); p.add_argument("--startup-wait",type=float,default=3)
    p.add_argument("--codex",default="codex")
    p.add_argument("--label",default=machine_name(),help="machine name shown in the report")
    a=p.parse_args()
    if not sys.stdin.isatty() or not sys.stdout.isatty(): p.error("run directly in an interactive terminal")
    shell=os.environ.get("SHELL","/bin/sh")
    cases=[
      ("bare terminal",None),
      ("Claude",[a.claude]),
      ("tmux",["tmux","-L",SOCK,"new-session",shell]),
      ("tmux + Claude",["tmux","-L",SOCK,"new-session",a.claude]),
      ("Codex",[a.codex]),
      ("tmux + Codex",["tmux","-L",SOCK,"new-session",a.codex]),
    ]
    fd=0; saved=termios.tcgetattr(fd); rows=[]
    try:
        tty.setraw(fd)
        # Keep signal generation enabled so Ctrl+C always raises KeyboardInterrupt.
        attrs=termios.tcgetattr(fd); attrs[3] |= termios.ISIG
        termios.tcsetattr(fd,termios.TCSANOW,attrs)
        for i,(name,cmd) in enumerate(cases,1):
            result=capture_direct(i,len(cases),name,fd) if cmd is None else capture(i,len(cases),name,cmd,fd,a.startup_wait)
            rows.append((name,*result))
    finally:
        out(RESET); termios.tcsetattr(fd,termios.TCSADRAIN,saved)
        subprocess.run(["tmux","-L",SOCK,"kill-server"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    w=max(map(len,(r[0] for r in rows))); print(f"\nTerminal key-byte results — {a.label}\n")
    print(f"{'Environment':<{w}}  {'Enter':<28}  {'Shift+Enter':<28}  Result"); print(f"{'-'*w}  {'-'*28}  {'-'*28}  {'-'*9}")
    for name,e,s,status in rows:
        result="ERROR" if status!="ok" else ("DISTINCT" if e!=s else "IDENTICAL")
        print(f"{name:<{w}}  {hx(e):<28}  {hx(s):<28}  {result}")
    return 0
if __name__=="__main__": raise SystemExit(main())
