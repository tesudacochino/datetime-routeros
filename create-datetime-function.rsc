# Written by Phillip Stromberg in 2019
# Licensed under the MIT license

:global datetime do={

    # PART 1 - THE BASICS

    :local months {
        "jan"="01"
        "feb"="02"
        "mar"="03"
        "apr"="04"
        "may"="05"
        "jun"="06"
        "jul"="07"
        "aug"="08"
        "sep"="09"
        "oct"="10"
        "nov"="11"
        "dec"="12"
    }

    :local monthAbbrs [:toarray ""]
    :foreach abbr,idx in=$months do={
        :set ($monthAbbrs->$idx) $abbr;
    }

    :local dNames {"Sunday"; "Monday"; "Tuesday"; "Wednesday"; "Thursday"; "Friday"; "Saturday"}

    :local dt
    :local ti

    # this loop protects in the rare event we hit midnight between getting the date and time
    do {
        :set dt [/system clock get date]
        :set ti [/system clock get time]
    } while=($dt != [/system clock get date])

    :local b;
    :local Y;
    :local y;
    :local m;
    :local d;
    :local ymd;
    :local datestr;

    :local H [:pick $ti 0 2];
    :local I ($H % 12);
    :local p;

    :if ($I = 0) do={
        :set I 12
    }

    :if ( [:pick $dt 4] = "-" ) do={
        # new RouterOS 7.10 change, datetime is returned in ISO 8601
        :set m [:pick $dt 5 7];
        :set Y [:pick $dt 0 4];
        :set y [:pick $dt 2 4];
        :set b ($monthAbbrs->$m);
        :set d [:pick $dt 8 10];
        :set ymd $dt;
        # this emulates the old behavior
        :set datestr "$b/$d/$Y";
    } else={
        # older RouterOS versions return the date more like "apr/26/2024"
        :set b [:pick $dt 0 3];
        :set Y [:pick $dt 7 11];
        :set y [:pick $dt 9 11];
        :set m ($months->$b);
        :set d [:pick $dt 4 6];
        :set ymd "$Y-$m-$d";
        :set datestr $dt;
    }

    :if ([:len $I] < 2) do={
        :set I ("0$I")
    }

    :if ($H < 12) do={
        :set p "am"
    } else={
        :set p "pm"
    }

    # PART 2 - CREATE GMT OFFSET STRING

    :local oInt [/system clock get gmt-offset]
    :local oSign

    # GMT offset is returned as an unsigned integer containing a signed integer
    # so for negative numbers, it comes out as 4 billion instead of, say -18000
    # Additionally, the bitwise NOT operator doesn't work for numbers so we 
    # have to do this ugly thing here
    :if ($oInt > 2147483647) do={
        :set oInt (4294967296 - $oInt)
        :set oSign "-"
    } else={
        :set oSign "+"
    }

    # GMT Offset Hours
    :local oHrs ($oInt / 3600)
    # GMT Offset Minutes
    :local oMin (($oInt % 3600) / 60)

    :if ([:len $oHrs] < 2) do={
        :set oHrs ("0$oHrs")
    }

    :if ([:len $oMin] < 2) do={
        :set oMin ("0$oMin")
    }

    :local z "$oSign$oHrs$oMin"

    # PART 3 - DAY OF THE WEEK CALCULATION
    # this entire section inspired by https://cs.uwaterloo.ca/~alopez-o/math-faq/node73.html

    :local leapYear ( (($Y % 4) = 0) && ( (($Y % 100) != 0) || (($Y % 400) = 0) ) )

    :local monthKeyVal {1; 4; 4; 0; 2; 5; 0; 3; 6; 1; 4; 6}

    :local mkv ($monthKeyVal->($m-1))

    # January and February of a leap year get special treatment
    :if ( $leapYear && ( $m <= 2 ) ) do={
        :set mkv ($mkv - 1)
    }
    
    :local w ( (($y / 4) + $d) + $mkv )
    :if ($Y >= 2000) do={
        :set w ($w + 6)
    }
    :set w ((($w + $y) - 1) % 7)

    :local A ($dNames->w)
    :local a [:pick $A 0 3]

    # PART 4 - RETURN the results as an dictionary/array

    :local dtobject {
        "b"=$b
        "m"=$m
        "d"=$d
        "Y"=$Y
        "y"=$y
        "time"=$ti
        "H"=$H
        "M"=[:pick $ti 3 5]
        "S"=[:pick $ti 6 8]
        "date"=$datestr
        "ymd"=$ymd
        "I"=$I
        "p"=$p
        "z"=$z
        "w"=$w
        "A"=$A
        "a"=$a
        "Z"=[/system clock get time-zone-name]
    }

    :return $dtobject
}
