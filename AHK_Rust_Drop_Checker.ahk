#SingleInstance Force
#Warn
rust_checker.Start()
Return

*F1::rust_checker.Toggle()
*Escape::ExitApp

~^s::
	IfWinActive, % A_ScriptName
    {
        Reload
        ExitApp
    }
Return

/*
; On load > make gui
;   Gui should have a close button and minimize button
; Scrape https://twitch.facepunch.com/ to see if 
;   Check for keywords online offline'
; If scrape returns successful, populate gui with people
;   + Set timer to continuously check the site every X amount of seconds
*/

/*
user.username    
user.profile_url
user.avatar_url  
user.status      
user.drop_name   
user.drop_pic_url
*/

/*
error codes
-1 = HTML can't be downloaded
-2 = Error parsing HTML
-3 = No streamer data to access
-4 = No streamer HTML to parse
*/

Class rust_checker
{
    Static  streamer_data   := ""
            , title         := "AHK Rust Drop Checker"
            , version       := 1.0
            , html          := ""
            , err_last      := ""
            , err_log       := ""
            , checker       := True
    Static  path            := {app             : A_AppData "\AHK_Rust_Drops"
                               ,img             : A_AppData "\AHK_Rust_Drops\img" 
                               ,streamers       : A_AppData "\AHK_Rust_Drops\streamers"
                               ,user            : A_AppData "\AHK_Rust_Drops\user"
                               ,log             : A_AppData "\AHK_Rust_Drops\log.txt"
                               ,settings        : A_AppData "\AHK_Rust_Drops\settings.ini"
                               ,img_online      : A_AppData "\AHK_Rust_Drops\img\Online.png"
                               ,img_offline     : A_AppData "\AHK_Rust_Drops\img\Offline.png" }
    Static  url             := {git_img         : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/blob/main/img"
                               ,git_img_online  : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Online%20Blank%203D.png"
                               ,git_img_offline : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/img/Offline%20Blank%203D.png"
                               ,git_ver         : "https://github.com/0xB0BAFE77/AHK_Rust_Drop/raw/main/version.txt"
                               ,facepunch       : "https://twitch.facepunch.com/" }
    Static  rgx             := {profile_url     : "<\s*?a\s*?href=""(.*?)"""
                               ,avatar_url      : "img\s+src=""(.*?)""\s+alt="
                               ,username        : "class=""streamer-name"".*?>(.*?)</"
                               ,status          : "online-status.*?>(.*?)<"
                               ,ext             : "\.(\w+)\s*?$"
                               ,drop_pic_url    : "img\s*?src=""(.*?)"".*?title="
                               ,drop_name       : "class=""drop-name"".*?>(.*?)</" }
    
    Start()
    {
        ;this.splash.start("Starting up " this.title)
        OnExit(this.use_method("shutdown"))
        
        ;this.splash.update("Downloading Streamer Data")
        If this.get_streamer_data()
            this.error(A_ThisFunc, "Error getting streamer data.", 1)
        
        ;this.splash.update("Creating folders")
        If this.folder_check()                     ; Check for program folder
            this.error(A_ThisFunc, "Folder's cannot be created.", 1)
        
        ;this.splash.start("Loading log")
        If this.load_log()
            this.error(A_ThisFunc, "Unable to load error log.", 1)
        
        ;this.splash.update("Downloading images")
        If this.download_images()
            this.error(A_ThisFunc, "Unable to download images.", 1)
        
        ;this.splash.update("Creating GUI")
        this.main_gui.create(this.streamer_data)
        
        ;this.splash.update("Getting the paddles to start the heartbeat. CLEAR!!!")
        this.heartbeat()
        
        ;this.splash.update("Finished!")
        ;this.splash.finish()
        Return
    }
    
    heartbeat(bpm:=2)
    {
        ; Get fresh data
        this.get_streamer_data()
        ; Update GUI with new info
        this.main_gui.update_gui(this.streamer_data)
        ; Do comparison
        this.notify_check()
        Return
    }
    
    notify_check()
    {
        ; Get fresh data
        this.get_streamer_data()
        ; Compare fresh data to old notify list
        For index, user in this.streamer_data
        {
            If (user.status) && (notify_list[user.username] = 1)
                this.notify_user()
        }
        ; UPdate notify list
    }
    
    notify_user()
    {
        MsgBox, This [user] is on! Make the icon flash!
        Return
    }
    
    get_streamer_data()
    {
        err := this.update_streamer_html()  ? -1  ; Get HTML or -1 if error
            : this.parse_streamer_html()    ? -2  ; Parse HTML or -2 error
            :                                  0  ; Else 0 for success
        Return err
    }
    
    folder_check()
    {
        Status := 0
        Loop, Parse, % "app|img|user|streamers", % "|"
            If !FileExist(this.path[A_LoopField])
            {
                FileCreateDir, % this.path[A_LoopField]
                If ErrorLevel
                    this.error(A_ThisFunc, "Unable to create directory: " this.path[A_LoopField])
                    , status := 1
            }
        
        For index, user in this.streamer_data
            If !FileExist(this.path.app "\" user.username)
            {
                FileCreateDir, % this.path.app "\" user.username
                If ErrorLevel
                    this.error(A_ThisFunc, "Unable to create streamer directory: " this.path.app "\" user.username)
                    , status := 1
            }
        
        Return status
    }
    
    load_log()
    {
        status := 0
        FileRead, err_log, % this.path.log
        If ErrorLevel
        {
            FileAppend, % (err_log := "Log file created: " A_Now "`n`n"), this.path.log
            If ErrorLevel
                this.error(A_ThisFunc, "No error log exists and could not create a new one.", 1)
                , status := 1
        }
        this.err_log := err_log
        Return status
    }

    download_images()
    {
        Status := 0
        ; Make sure streamer data is there
        If !IsObject(this.streamer_data)
            Return -3
        
        ; Loop through each streamer, download, and save their avatars and item drops
        For index, user in this.streamer_data
            For i, type in ["avatar","drop_pic"]
                ext         := ""
                , url       := user[type "_url"]
                , RegExMatch(url, this.rgx.ext, ext)
                , path      := this.path.streamers "\" user.username
                , file      := type "." ext
                , this.streamer_data[index][type "_loc"] := path "\" file
                , (this.img_getter(url, path, type "." ext) = 1) ? status := 1 : ""
        
        ; Get status online/offline icons
        (this.img_getter(this.url.git_img_online, this.path.img, "Online.png")  = 1)
            ? status := 1 : ""
        (this.img_getter(this.url.git_img_offline, this.path.img, "Offline.png")  = 1)
            ? status := 1 : ""
        
        Return Status
    }
    
    ; Scrape HTML from streamer page
    ; Saves html to this.html
    ; Returns 1 = success, 0 = failure
    update_streamer_html()
    {
        this.html   := ""
        , status    := 0
        , web       := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        
        Try
            web.Open("GET", this.url.facepunch), web.Send()
        Catch
            this.error(A_ThisFunc, "Error getting data from site: " this.url.facepunch)
            , status := 1
        this.html   := web.ResponseText
        
        Return status
    }
    
    ; rust_checker.streamer_data properties:
    ; .profile_url      URL to user's twitch or youtube profile (whichever was provided by the site)
    ; .avatar_url       URL to user's gaming avatar
    ; .avatar_loc       Location on disk where avatar is saved
    ; .username         User's username (Redudant, right?)
    ; .status           User's status of online or offline
    ; .drop_pic_url     URL picture of this user's Rust drop
    ; .drop_pic_loc     Location on disk where Rust drop picture is saved
    ; .drop_name        The name of the drop
    ; .notify           If true, you want notified when this streamer comes online
    parse_streamer_html()
    {
        strm_list   := []
        , info      := {}
        , start     := False
        , html      := this.html
        , html      := StrReplace(html  , "`r"    , "")
        , html      := StrReplace(html  , "`n"    , " ")
        , html      := RegExReplace(html, ">\s*?<", ">`n<")
        , match     := match1 := ""
        , this.streamer_data  := ""
        
        If (this.html = ""){
            this.error(A_ThisFunc, "No HTML to parse.")
            Return -4
        }
        
        Loop, Parse, % this.html, `n
            If (start = False)                                                                           ; Skip all unnecessary starting lines
            {
                InStr(A_LoopField, "STREAMER DROPS") ? start := true : ""                                ; Check if start is finished
                Continue
            }
            Else If InStr(A_LoopField, "general-drops")                                                  ; Break when the user drops are done
                Break
            Else  RegExMatch(A_LoopField, this.rgx.profile_url  , match) ? info := {profile_url:match1}  ; Start of new user. Get URL.
                : RegExMatch(A_LoopField, this.rgx.avatar_url   , match) ? info.avatar_url   := match1   ; Get avatar
                : RegExMatch(A_LoopField, this.rgx.username     , match) ? info.username     := match1   ; Get username
                : RegExMatch(A_LoopField, this.rgx.status       , match) ? info.status       := (match1
                                                                                            ="Live"?1:0) ; Get status
                : RegExMatch(A_LoopField, this.rgx.drop_pic_url , match) ? info.drop_pic_url := match1   ; Get URL for drop pic
                : RegExMatch(A_LoopField, this.rgx.drop_name    , match) ? info.drop_name    := match1   ; Get pic name
                : InStr(A_LoopField, "</a>")                             ? strm_list.Push(info)          ; End of user. Write info.
                : ""                                                                                     ; Else, do nothing
        
        this.streamer_data := strm_list
        
        Return (this.streamer_data = "" ? 1 : 0)
    }
    
    img_getter(url, path, file_name, force:=0)
    {
        Status := 0
        If !FileExist(path)
        {
            FileCreateDir, % path
            (status := ErrorLevel)
                ? this.error(A_ThisFunc, "Save path does not exist and could not be created."
                    . "`npath: " path)
                : ""
        }
        
        If !FileExist(path "\" file_name) || (force = 1)
        {
            UrlDownloadToFile, % url, % path "\" file_name
            (status := ErrorLevel)
                ? this.error(A_ThisFunc, "Could not download file from url and save to location."
                    . "`nurl: " url "`nlocation: " path "\" file_name) : ""
        }
        
        Return status
    }
    
    use_method(method, param:="")
    {
        bf := ObjBindMethod(this, method, param*)
        Return bf
    }
    
    shutdown()
    {
        this.save_log()                         ; Save error logs
        this.main_gui.save_settings()                ; Save settings
        
        ; MsgBox, 0x4, Cleanup, Delete downloaded images and other files?
        ; IfMsgBox, Yes
        ;     FileRemoveDir, % this.path.app, 1
        Return
    }
    
    save_log()
    {
        FileDelete, % this.path.log
        If Errorlevel
            FileAppend, % this.err_log, % this.path.log ".dump"
        Else
            FileAppend, % this.err_log, % this.path.log
    }
    
    Class main_gui
    {
        ; hwnd properties:
        ; gui               
        ; error_txt
        Static  hwnd            := {}
                , notify_list   := {}
                , visible       := True
        
        create(streamer_data)
        {
            pad         := 10
            , padh      := Floor(pad/2)
            , padq      := Floor(pad/4)
            , pad2      := pad*2
            , gui_w     := 640
            , gui_h     := 800
            , card_w    := 200
            , card_h    := 270
            , btn_w     := 80
            , btn_h     := 30
            , err_gb_w  := gui_w/2 - pad*2
            , err_gb_h  := 40
            , err_txt_w := err_gb_w - 2
            
            Gui, Main:New, +Caption +HWNDhwnd, Rust Streamer Checker
                this.hwnd.gui := hwnd
            Gui, Main:Default
            Gui, Margin, % pad, % pad
            Gui, Color, 0x000000
            Gui, Font, s12 cWhite
            
            ; Possible auto-mode later
            ; Gui, Add, Checkbox, xm ym, Auto-Mode
            
            ; Build streamer area
            For index, user in streamer_data
            {
                mx   := Mod(A_Index, 3)
                , (mx = 0 ? mx := 3 : "")
                , my := Ceil(A_Index/3) 
                , x  := (card_w * (mx-1)) + (pad*mx)
                , y  := (pad*my) + (card_h * (my-1))
                , this.add_card(index, user, card_w, card_h, x, y)
            }
            
            ; Add error area to display errors as they come
            Gui, Add, GroupBox, w%err_gb_w% h%err_gb_h% xm y+%pad% Section, Error Messages:
            Gui, Font, s8 cWhite
            Gui, Add, Edit, w%err_gb_w% xp yp+20 ReadOnly R1, FAKE ERROR MESSAGE FOR TESTING!
                this.hwnd.error_txt
            ; Minimize button
            x := gui_w/2 + pad
            y := (card_h+pad) * 3 + pad
            Gui, Font, s10
            Gui, Add, Button, w%btn_w% h%btn_h% x%x% y%y% HWNDhwnd, Minimize
            ; Clean up button
            ;Gui, Add, Button, w%btn_w% h%btn_h% x+%pad2% yp HWNDhwnd, Clean Up
            ; Add exit and min button
            x := gui_w - pad - btn_w
            Gui, Add, Button, w%btn_w% h%btn_h% x%x% yp HWNDhwnd, Close
                this.add_method(hwnd, "close")
            
            bf := ObjBindMethod(this, "WM_LBUTTONDOWN", A_Gui)
            OnMessage(0x0201, bf)
            
            ; Create and load notify list and other saved settings
            this.notify_list := {}
            For index, user in streamer_data
                this.notify_list[user.username] := 0
            this.load_settings()
            
            x := A_ScreenWidth + 100
            Gui, Show, AutoSize x%x% y100 ;Center, % this.title
            Return
        }
        
        load_settings()
        {
            ; Get settings from hard drive
            ;IniRead, settings
            MsgBox Still need to write %A_ThisFunc%.
            Return
        }
        
        save_settings()
        {
            MsgBox Still need to write %A_ThisFunc%.
            Return
        }
        
        add_card(index, user, sw, sh, sx, sy)
        {
            pad             := 10
            , pad2          := pad*2
            , padh          := Floor(pad/2)
            , padq          := Floor(pad/4)
            , status_w      := 80
            , status_h      := 20
            , status_txt_w  := 70
            , status_txt_h  := 16
            , avatar_w      := 50
            , avatar_h      := 50
            , drop_pic_w    := sw - pad
            , drop_pic_h    := drop_pic_w
            , notify_cb_w   := sw/2
            , notify_cb_h   := 20
            
            Gui, Main:Default
            Gui, Font, S12 Bold q5 cWhite
            ; Create groupbox border and add username to groupbox
            Gui, Add, GroupBox, w%sw% h%sh% x%sx% y%sy%, % user.username
            ; Add status background to groupbox border
            x := sw - status_w - padh
            Gui, Add, Picture, w%status_w% h%status_h% xp+%x% yp HWNDhwnd
                , % rust_checker.path[(user.status ? "img_online" : "img_offline")]
                this.hwnd[user.username].status_pic := hwnd
            ; Add status text
            Gui, Font, S10 Bold q5 cBlack
            Gui, Add, Text, w%status_txt_w% h%status_txt_h% xp+5 yp+2 +Center HWNDhwnd
                , % user.status ? "LIVE" : "OFFLINE"
                this.transparent_bg(hwnd)
                this.hwnd[user.username].status_txt := hwnd
            
            ; Drop_pic image
            x := sx + padh
            Gui, Add, Picture, w%drop_pic_w% h%drop_pic_h% x%x% yp+20 +Border, % user.drop_pic_loc
            ; Drop_name description
            h := 30
            Gui, Font, S10 Norm q5 cWhite
            Gui, Add, Text, wp h%h% xp y+-%h% HWNDhwnd +Center +Border +0x200, % user.drop_name
            ; User's icon
            Gui, Add, Picture, w%avatar_w% h%avatar_h% xp y+0 +Border, % user.avatar_loc
            ; Add notify checkbox
            Gui, Font, S10 Bold q5
            w := sw - avatar_w - pad2
            y := notify_cb_h
            Gui, Add, Checkbox, w%w% h%notify_cb_h% x+%padh% y+-%y% +HWNDhwnd, Notify Me!
                this.hwnd[user.username].notify := hwnd
                bf := ObjBindMethod(this, "set_notify_status", index)
                GuiControl, +g, % hwnd, % bf
            ;this.set_notify_status()
            
            ; Add "notify me" checkbox below group box
            ;Gui, Add, Checkbox, 
            ;MsgBox, % "Gui card check!`n" "status_w: " status_w "`nstatus_h: " status_h "`navatar_w: " avatar_w "`navatar_h: " avatar_h "`ndrop_pic_w: " drop_pic_w "`ndrop_pic_h: " drop_pic_h "`nsw: " sw "`nsh: " sh "`nsx: " sx "`nsy: " sy 
            Return
        }
        
        set_notify_status(index, hwnd, GuiEvent, EventInfo, ErrLevel:="")
        {
            name    := this.streamer_data[index].username
            GuiControlGet, notify_state, , % CtrlHwnd
            If (this.streamer_data[index].status){
                GuiControl, , % hwnd, 0
                this.notify_list[name] := 0
            }
            Else
            {
                this.notify_list[name] := notify_state
            }
            Return
        }
        
        update_gui(streamer_data)
        {
            For index, user in streamer_data
            {
                GuiControl, , % this.hwnd[user.username].status_pic
                    , % this.path[(user.status ? "img_online" : "img_offline")]
                GuiControl, , % this.hwnd[user.username].status_txt, idk
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        HERE        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
            }
            MsgBox Still need to write %A_ThisFunc%
            Return
        }
        
        transparent_bg(hwnd)
        {
            GuiControl, +BackgroundTrans, % hwnd
            Return
        }
        
        WM_LBUTTONDOWN()
        {
            If (A_Gui = "Main"){
                MouseGetPos, x, y, win, con
                If !InStr(con, "button")
                    SendMessage, 0x00A1, 2,,, A
            }
            
            Return
        }
        
        Show()
        {
            Gui, Main:Show
        }
        
        Hide()
        {
            Gui, Main:Hide
        }
        
        close()
        {
            MsgBox, 0x4, Exiting, Are you sure you want to exit?
            IfMsgBox, Yes
                ExitApp
            Return
        }
    }
    
    Class splash
    {
        start(msg)
        {
            pad := 10
            Gui, splash:New, -Caption
            Gui, splash:Default
            Gui, Margin, % pad, % pad
            Gui, Add, Text, xm ym w500 h150, % msg
            Gui, Show, AutoSize Center
            this.animate()
            Return
        }
        
        update(txt)
        {
            this.txt := txt
            Return
        }
        
        animate()
        {
            MsgBox animation code here
            Return
        }
        
        finish()
        {
            Gui, splash:Destroy
            Return
        }
    }
    
    error(call:="func here", msg:="msg here", option:=0)
    {
        this.err_last   := A_Now "`nCall: " call "`nMessage: " msg
        this.err_log    .= this.err_last "`n`n"
        MsgBox, % this.err_last
        
        If (option = -1)
            ExitApp
        If (option = 1)
        {
            MsgBox, 0x4, Error, Do you want to reload the script and try again?
            IfMsgBox, Yes
                Reload
        }
        
        Return 0
    }
    
}

; Used for troubleshooting
msg(txt)
{
    MsgBox, % txt
    Return
}


