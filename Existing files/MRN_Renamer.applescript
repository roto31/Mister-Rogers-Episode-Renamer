#!/usr/bin/env osascript
(*
Mister Rogers' Neighborhood Episode Renamer - macOS AppleScript Wrapper
Provides drag-and-drop and Automator integration for the Python renamer.

Installation:
1. Save as "MRN_Renamer.app" in Applications folder
2. Or use with Automator: Automator.app > New > Quick Action
   - Add "Run Shell Script" action
   - Paste the shell command below

For Automator Quick Action:
/usr/bin/python3 /path/to/misterrogers_renamer.py --interactive

*)

on run
    display dialog "Mister Rogers' Neighborhood Episode Renamer" & return & return & ¬
        "Choose an action:" buttons {"Lookup Episode", "Process Files", "Cancel"} default button 1
    
    set the button_pressed to button returned of the result
    
    if button_pressed = "Lookup Episode" then
        tell application "Terminal"
            do script "/usr/bin/python3 /path/to/misterrogers_renamer.py --interactive"
        end tell
    else if button_pressed = "Process Files" then
        choose folder with prompt "Select folder containing video files:"
        set chosen_folder to the result as text
        
        -- First show a preview (dry run)
        tell application "Terminal"
            do script "/usr/bin/python3 /path/to/misterrogers_renamer.py " & quoted form of chosen_folder
        end tell
        
        display dialog "Review the changes above. Click 'Rename' to proceed:" buttons {"Cancel", "Rename"} default button 1
        
        if button returned of the result = "Rename" then
            tell application "Terminal"
                do script "/usr/bin/python3 /path/to/misterrogers_renamer.py " & quoted form of chosen_folder & " --commit"
            end tell
        end if
    end if
end run

on open the_files
    (*
    Drag-and-drop handler - called when files are dropped on the app
    *)
    repeat with a_file in the_files
        set file_path to POSIX path of a_file
        tell application "Terminal"
            do script "/usr/bin/python3 /path/to/misterrogers_renamer.py " & quoted form of file_path & " --commit"
        end tell
    end repeat
end open
