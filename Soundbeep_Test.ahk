#SingleInstance, Force
#NoEnv
#Warn
SetBatchLines, -1

sound_beep()
MsgBox well?
ExitApp

*Esc::ExitApp

sound_beep(){
    
                       ;  C            C#            D            D#            E            F            F#            G            G#            A            A#            B
    Static note_arr := [{"C":32.70   ,"CS":34.65   ,"D":36.71   ,"DS":38.89   ,"E":41.2    ,"F":43.65   ,"FS":46.25   ,"G":49      ,"GS":51.91   ,"A":55.00   ,"AS":58.27   ,"B":61.74   }   ; Octave 1
                       ,{"C":65.41   ,"CS":69.3    ,"D":73.42   ,"DS":77.78   ,"E":82.41   ,"F":87.31   ,"FS":92.5    ,"G":98      ,"GS":103.8   ,"A":110.00  ,"AS":116.5   ,"B":123.5   }   ; Octave 2
                       ,{"C":130.80  ,"CS":138.6   ,"D":146.8   ,"DS":155.6   ,"E":164.8   ,"F":174.6   ,"FS":185     ,"G":196     ,"GS":207.7   ,"A":220.00  ,"AS":233.1   ,"B":246.9   }   ; Octave 3
                       ,{"C":261.60  ,"CS":277.2   ,"D":293.7   ,"DS":311.1   ,"E":329.6   ,"F":349.2   ,"FS":370     ,"G":392     ,"GS":415.3   ,"A":440.00  ,"AS":466.2   ,"B":493.9   }   ; Octave 4
                       ,{"C":523.30  ,"CS":554.4   ,"D":587.3   ,"DS":622.3   ,"E":659.3   ,"F":698.5   ,"FS":740     ,"G":784     ,"GS":830.6   ,"A":880.00  ,"AS":932.3   ,"B":987.8   }   ; Octave 5
                       ,{"C":1046.50 ,"CS":1108.73 ,"D":1174.66 ,"DS":1244.51 ,"E":1318.51 ,"F":1396.91 ,"FS":1479.98 ,"G":1567.98 ,"GS":1661.22 ,"A":1760.00 ,"AS":1864.66 ,"B":1975.53 }   ; Octave 6
                       ,{"C":2093.00 ,"CS":2217.46 ,"D":2349.32 ,"DS":2489.02 ,"E":2637.02 ,"F":2793.83 ,"FS":2959.96 ,"G":3135.96 ,"GS":3322.44 ,"A":3520.00 ,"AS":3729.31 ,"B":3951.07 }   ; Octave 7
                       ,{"C":4186.01 ,"CS":4434.92 ,"D":4698.64 ,"DS":4978.03 ,"E":5274.04 ,"F":5587.65 ,"FS":5919.91 ,"G":6271.93 ,"GS":6644.88 ,"A":7040.00 ,"AS":7458.62 ,"B":7902.13 } ] ; Octave 8
    
    For octave, note_range in note_arr
        For note, freq in note_range
        {
            SoundBeep, % freq, 500
            ToolTip, % "octave: " octave "`nnote: " note "`nfreq: " freq
            Sleep, 500
        }
    Return
}





play_ff_fanfare()
{
    i := 40
    Loop
    {
        SoundBeep, % s, 50
        ToolTip, % s
        Sleep, 50
    }
    Until (s > 32767)
    Return
}
