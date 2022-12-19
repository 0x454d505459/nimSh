import utilities/tlib
import osproc, strutils, os, streams

from posix import execvp, fork, wait

const
    red     = static rgb(255,35,64)
    green   = static rgb(76,255,157)
    blue    = static rgb(90,153,255)
    violet  = static rgb(255,117,255)
    yellow  = static rgb(253,255,105)
    blank   = static def()

var 
    history:seq[string]
    historyReversed:seq[string]
    fgProcess:Process
    hostname:string

proc endProcess() {.noconv.} =
    fgProcess.terminate()

proc getHostName():string =
    return readFile("/etc/hostname").strip()

proc clearPrompt() =
    moveCursorLeft 1
    stdout.write " "
    moveCursorLeft 1

proc shellError(cmd,msg:string) =
    echo "\n" & getAppFilename().splitPath()[1] & ": " & cmd & " : " & msg

proc runCommand(args:seq[string]) =
    let argsArr = allocCStringArray(args[0..^1].toOpenArray(0,args.high))
    echo ""    
    let forked = fork()
    if forked < 0:
        echo "Error while forking"
        quit(1)
    elif forked > 0:
        deallocCStringArray(argsArr)
        # https://github.com/kamalmarhubi/shell-workshop
        wait(nil)
    else:
        discard execvp(cstring(args[0]), argsArr)
    
    
proc prompt() =
    let pwd = os.getCurrentDir().split("/")[^1]
    stdout.write(green & hostname & red & ":[" & blue & os.getEnv("USER") & red & "]" & violet & pwd & yellow & "$ " & blank)

template moveHistory(history,reversed:untyped) =
    if len(history) == 0: continue
    let currentCmd = history.pop()
    reversed.add(currentCmd)
    if len(keys) > 0:
        for i in 0..len(keys)-1:
            clearPrompt()
        keys = @[]
    
    for ck in currentCmd:
        keys.add Key(ck)
    
    stdout.write currentCmd


setControlCHook(endProcess)
hostname = getHostName()
while true:
    prompt()

    var 
        keys:seq[Key]
        keyIndex:int

    keyIndex = len(keys)
    while true:
        let 
            c = tlib.getKey()
        
        case c
        of CtrlC, CtrlD:
            stdout.write "\nexit\n"
            quit(0)
        
        of CtrlA:
            echo keys

        of Left:
            if keyIndex >= keys.len(): continue
            keyIndex += 1
            moveCursorLeft 1
        
        of Right:
            if keyIndex <= 0: continue
            keyIndex -= 1
            moveCursorRight 1

        of Enter:
            break
            
        of Up:
            moveHistory(history, historyReversed)

        of Down:
            moveHistory(historyReversed, history)

        of CtrlL:
            runCommand(@["clear"])
            prompt()

        of Backspace:
            if keys.len() > 0:
                discard keys.pop()
                clearPrompt()
        else:
            let insertPos = len(keys) - keyIndex
            keys.insert(c,insertPos)
            stdout.write(keys[insertPos..^1].join(""))            
            keyIndex = 0
    
    var str:string
    for k in keys:
        str.add $k
    keys = @[]

    if str == "" or str == " ": echo "";continue

    let args = str.split(" ")
    history.add str

    case args[0]:
        of "history":
            echo history
            continue
            
        of "cd":
            if len(args) == 1: shellError(args[0], "Nowhere to go"); continue
            if not os.dirExists(args[1]): shellError(args[0], "No such file or directory");continue
            os.setCurrentDir(args[1])
            echo ""
            continue

    
    if findExe(args[0], true, [""]) == "": shellError(args[0], "Command not found");continue
    runCommand(args)
    