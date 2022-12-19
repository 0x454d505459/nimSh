import utilities/tlib
import strutils, os

from posix import execvp, fork, wait

# Static colors to be sure they are evaluated at compile time
const
    red = static rgb(255, 35, 64)
    green = static rgb(76, 255, 157)
    blue = static rgb(90, 153, 255)
    violet = static rgb(255, 117, 255)
    yellow = static rgb(253, 255, 105)
    blank = static def()

var
    history: seq[string]            # history stack
    historyReversed: seq[string]    # history stack reversed
    hostname: string                # Computer host name


proc getHostName(): string =
    ## Returns the device's hostname (*NIX only)
    return readFile("/etc/hostname").strip()

proc clearPrompt() =
    ## Clears the prompt by one char
    # Move the cursor to left by one to replace the last char
    moveCursorLeft 1
    # Replace the last char
    stdout.write " "
    # Move the cursor left again as writing to stdout moves the
    # cursor to the right
    moveCursorLeft 1

proc shellError(cmd, msg: string) =
    ## Show a BASH-like error using the following format
    ## executableName : Command : Message
    echo "\n" & getAppFilename().splitPath()[1] & ": " & cmd & " : " & msg

proc runCommand(args: seq[string]) =
    ## Runs a program using fork and exec from the posix wrapper
    # Create a cArray of cStrings from the args as exec only accepts c types
    let argsArr = allocCStringArray(args[0..^1].toOpenArray(0, args.high))
    # Line break
    echo ""
    # Fork the process
    let forked = fork()
    # Check what we are
    if forked < 0:
        # Fork failed
        echo "Error while forking"
        quit(1)
    elif forked > 0:
        # Here we are the parent proccess so we free our cArray of cString
        deallocCStringArray(argsArr)
        # we wait for our child to finish
        # https://github.com/kamalmarhubi/shell-workshop
        wait(nil)
    else:
        # We are the child
        # We exec the wanted program (thankfully it looks by itself in the path)
        discard execvp(cstring(args[0]), argsArr)


proc prompt() =
    ## Renders the BASH-like prompte
    # Get the last part of the current working directory
    let pwd = os.getCurrentDir().split("/")[^1]
    # Writes to standard output the prompt using the following format
    # GREEN Hostname RED :[BLUE USERNAME RED] VIOLET Pwd YELLOW $
    # which looks like this
    # hostname:[username]pwd$ 
    stdout.write(green & hostname & red & ":[" & blue & os.getEnv("USER") &
            red & "]" & violet & pwd & yellow & "$ " & blank)

template moveHistory(history, reversed: untyped) =
    ## Template for navigating the history stacks
    if len(history) == 0: continue
    # store the last command from the history
    let currentCmd = history.pop()
    # add it to the reversed history
    reversed.add(currentCmd)

    # clear our prompt if it has any keys in it
    if len(keys) > 0:
        # replace every single char with whitespaces
        for i in 0..len(keys)-1:
            clearPrompt()
        
        # clear our registered keys
        keys = @[]
    # for the loaded add all associeted keys
    for ck in currentCmd:
        keys.add Key(ck)

    # write the command to the screen
    stdout.write currentCmd

# get the system hostname at start
hostname = getHostName()
while true:
    # render the prompt
    prompt()

    var
        keys: seq[Key]
        keyIndex: int

    keyIndex = len(keys) # says we are at the last positions in our keys
    while true:
        let
            c = tlib.getKey() # get a single key

        case c
        of CtrlC, CtrlD:
            # Exit the shell
            stdout.write "\nexit\n"
            quit(0)

        of CtrlA:
            # To debut show keys
            echo keys

        of Left:
            # left arrow key
            # pass if we are already at the start of the keys
            if keyIndex >= keys.len(): continue
            keyIndex += 1       # increment our key position by one (keyIndex works in reverse)
            moveCursorLeft 1    # move our cursor to the left

        of Right:
            # right arrow key
            # pass if are at end of the keys
            if keyIndex <= 0: continue
            keyIndex -= 1       # decrement our key position by one (keyIndex works in reverse)
            moveCursorRight 1   # move our cursor right

        of Enter:
            # suppositly we don't have any other keys to listen for
            break

        of Up:
            # go up in the history
            moveHistory(history, historyReversed)

        of Down:
            # go down in the history
            moveHistory(historyReversed, history)

        of CtrlL:
            # run the clear command
            runCommand(@["clear"])
            # show back the prompt
            prompt()

        of Backspace:
            # Remove a single key
            # Pass if we don't have any keys in our prompt
            if keys.len() > 0:
                # Remove the last key (need to rewrite for key position system)
                discard keys.pop()
                # Remove a single char from prompt
                clearPrompt()
        else:
            # We didn't handle the key
            # Get the insert position by reversing the keyIndex
            let insertPos = len(keys) - keyIndex
            # Insert the key at the correct position in the array
            keys.insert(c, insertPos)
            # write the char corresponding to that key + all thoses that follows (this thing is broken)
            stdout.write(keys[insertPos..^1].join(""))
            # reset our key index
            keyIndex = 0

    # Construc the string with all keys
    var str: string
    for k in keys:
        str.add $k
    
    # clear the keys
    keys = @[]

    # pass if we didn't imputed something relevant
    if str == "" or str == " ": echo ""; continue

    # add our command as is to the history
    history.add str

    # split our command into an array
    let args = str.split(" ")

    # handle built-ins
    case args[0]:
        of "history":
            # the entered command is history
            # show the history and jump to the next iteration
            echo history
            continue

        of "cd":
            # basic "cd" implementation
            if len(args) == 1: shellError(args[0], "Nowhere to go"); continue
            if not os.dirExists(args[1]): shellError(args[0],
                    "No such file or directory"); continue
            os.setCurrentDir(args[1])
            echo ""
            continue

    # We passed everything on top ^^
    # Look if the our command is in path
    if findExe(args[0], true, [""]) == "": shellError(args[0],
            "Command not found"); continue

    # finnaly run our command
    runCommand(args)
