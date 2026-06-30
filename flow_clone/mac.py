from __future__ import annotations

import subprocess
import time

import pyperclip


EDITABLE_ROLES = {
    "AXTextArea",
    "AXTextField",
    "AXSearchField",
    "AXComboBox",
}


def accessibility_is_trusted() -> bool:
    try:
        from ApplicationServices import AXIsProcessTrusted
    except Exception:
        return False
    return bool(AXIsProcessTrusted())


def focused_element_is_editable() -> bool:
    try:
        from ApplicationServices import (
            AXUIElementCopyAttributeValue,
            AXUIElementCreateSystemWide,
            AXUIElementIsAttributeSettable,
            kAXFocusedUIElementAttribute,
            kAXRoleAttribute,
            kAXValueAttribute,
        )
    except Exception:
        return False

    system = AXUIElementCreateSystemWide()
    err, focused = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute, None)
    if err != 0 or focused is None:
        return False

    err, role = AXUIElementCopyAttributeValue(focused, kAXRoleAttribute, None)
    if err == 0 and str(role) in EDITABLE_ROLES:
        return True

    try:
        err, settable = AXUIElementIsAttributeSettable(focused, kAXValueAttribute, None)
        return err == 0 and bool(settable)
    except Exception:
        return False


def copy_text(text: str) -> None:
    pyperclip.copy(text)


def _set_selected_text_on_element(element, text: str) -> tuple[bool, str]:
    try:
        from ApplicationServices import (
            AXUIElementSetAttributeValue,
            kAXSelectedTextAttribute,
        )
    except Exception:
        return False, "ApplicationServices unavailable"

    err = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute, text)
    if err == 0:
        return True, "selected-text"
    return False, f"selected-text err {err}"


def insert_text_with_accessibility(text: str, target_pid: int | None = None) -> tuple[bool, str]:
    try:
        from ApplicationServices import (
            AXUIElementCreateApplication,
            AXUIElementCopyAttributeValue,
            AXUIElementCreateSystemWide,
            kAXFocusedUIElementAttribute,
        )
    except Exception:
        return False, "ApplicationServices unavailable"

    if not accessibility_is_trusted():
        return False, "accessibility not trusted"

    system = AXUIElementCreateSystemWide()
    err, focused = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute, None)
    if err == 0 and focused is not None:
        inserted, detail = _set_selected_text_on_element(focused, text)
        if inserted:
            return True, f"system-focused {detail}"

    if target_pid is None:
        return False, "no target pid"

    app = AXUIElementCreateApplication(target_pid)
    err, focused = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute, None)
    if err != 0 or focused is None:
        return False, f"target focused err {err}"

    inserted, detail = _set_selected_text_on_element(focused, text)
    return inserted, f"target {detail}"


def paste_clipboard(target_pid: int | None = None) -> str:
    try:
        import Quartz
    except Exception:
        result = subprocess.run(
            [
                "osascript",
                "-e",
                'tell application "System Events" to keystroke "v" using command down',
            ],
            check=False,
        )
        return f"osascript exit {result.returncode}"

    command_key = 55
    v_key = 9

    def events():
        source = Quartz.CGEventSourceCreate(Quartz.kCGEventSourceStateCombinedSessionState)
        command_down = Quartz.CGEventCreateKeyboardEvent(source, command_key, True)
        v_down = Quartz.CGEventCreateKeyboardEvent(source, v_key, True)
        v_up = Quartz.CGEventCreateKeyboardEvent(source, v_key, False)
        command_up = Quartz.CGEventCreateKeyboardEvent(source, command_key, False)

        Quartz.CGEventSetFlags(command_down, Quartz.kCGEventFlagMaskCommand)
        Quartz.CGEventSetFlags(v_down, Quartz.kCGEventFlagMaskCommand)
        Quartz.CGEventSetFlags(v_up, Quartz.kCGEventFlagMaskCommand)
        Quartz.CGEventSetFlags(command_up, 0)
        return [command_down, v_down, v_up, command_up]

    for event in events():
        Quartz.CGEventPost(Quartz.kCGHIDEventTap, event)
        time.sleep(0.02)

    if target_pid is not None:
        time.sleep(0.12)
        for event in events():
            Quartz.CGEventPostToPid(target_pid, event)
            time.sleep(0.02)
        return f"global and pid {target_pid}"

    return "global"


def notify(title: str, message: str) -> None:
    escaped_title = title.replace('"', '\\"')
    escaped_message = message.replace('"', '\\"')
    subprocess.run(
        [
            "osascript",
            "-e",
            f'display notification "{escaped_message}" with title "{escaped_title}"',
        ],
        check=False,
    )
