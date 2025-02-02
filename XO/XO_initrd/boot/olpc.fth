\ OLPC boot script

visible

\ Returns a number identifying the XO version - 2 for XO-1, 3 for XO-1.5
: xo-version  ( -- n )  fw-version$ drop 1+ c@ [char] 0 -  ;

\ To pass hardware specific arguments we define the xo-1? and xo-1.5? flags   
\ Returns true if the machine is XO-1
: xo-1?  ( -- flag )  xo-version 2 =  ;

\ Returns true if the machine is XO-1.5
: xo-1.5?  ( -- flag )  xo-version 3 =  ;

\ Overclocking the  XO-1 is an example of the above.
\ Overclocking may affect reliability and longevity of the XO-1
\ Increases power consumption and decreases battery life per charge.
\ If you still want overclock your XO-1 to 500Mhz CPU, 200MHz bus speed
\ remove the back-slash ( "\" ) from the beginning of the next 3 lines only

\ xo-1? if
\	7de009e 5dd 4c000014 wrmsr
\ then

\ End overclock section 

\ We set hardware-specific  requirements based on the xo-version parameter.
\ in this case the desired OFW version
: desired-ofw-version$  ( -- adr len )
   xo-version case
      2 of  " q2e45 "  endof   \ XO-1
      3 of  " q3a56 "  endof   \ XO-1.5
      ( default )
         ." UNKNOWN XO VERSION" cr
      " q0000 "  rot
   endcase
;

\ Given a string like " q3a54 "  (note the trailing space)
\ or " q3a54b", return a numerical value that can be used
\ to compare OFW versions.
: $ofw-version-num  ( adr len -- n )  drop h# fffc6 -  (fw-version)  ;

\ Return the numerical value representing the currently-installed OFW version.
: this-ofw-version-num  ( -- n )  rom-pa (fw-version)  ;

\ Complain if the firmware is out of date
: check-ofw  ( -- )
   desired-ofw-version$ $ofw-version-num  this-ofw-version-num u>  if
      ." You need to update the firmware to "  desired-ofw-version$ type  cr
   then
;

\ Sets the DN macro to expand to the device name from which this script
\ was booted.  That's useful for subsequently booting the kernel from
\ the same device.
\ Also sets the PN macro depending on the XO version
: set-path-macros  ( -- )
   \ "O" game button forces boot from internal FLASH
   button-o game-key?  if
      " \boot"  pn-buf place
      " int:"   dn-buf place
      exit
   then

   \ Set DN to the device that was used to boot this script
   " /chosen" find-package  if                       ( phandle )
      " bootpath" rot  get-package-property  0=  if  ( propval$ )
         get-encoded-string                          ( bootpath$ )
         [char] \ left-parse-string  2nip            ( dn$ )
         dn-buf place                                ( )
      then
   then

   \ Set PN according to the XO version
   xo-version  case
      2 of  " \boot10"  endof
      3 of  " \boot15"  endof
      ( default )  " \" rot
   endcase  ( adr len )
   pn-buf place
;

\ We check if we are booting from USB or SDcard to specify device-specific parameters

: dn-contains?  ( $ -- flag )  " ${DN}" expand$  sindex 0>=  ;
: usb?    ( -- flag )  " /usb"     dn-contains?  ;
: sd?     ( -- flag )  " /sd"      dn-contains?  ;
: slot1?  ( -- flag )  " /disk@1"  dn-contains?  ;

: olpc-fth-boot-me  ( -- )
   set-path-macros

   \ We can pass boot-device-specific kernel arguments here with the PD macro
   \ PDEV1 tells Puppy Linux's init script where to find Puppy-specific files.
   \ If PDEV1 is omitted, Puppy searches for the files.  If a USB FLASH drive
   \ takes a long time to wake up after a USB reset, Puppy sometimes misses it,
   \ so it's better to avoid the search by telling Puppy where to find the files.  
   usb?  if
      " PDEV1=sda1"
   else
      sd?  if
         slot1?  if
            " PDEV1=mmcblk0p1"  \ External SD card
         else
            " PDEV1=mmcblk1p1"  \ Internal SD card
         then
      else
         " "   \ Internal raw NAND
      then
   then
   " PD" $set-macro

   check-ofw

   " console=ttyS0,115200 console=tty0 fbcon=font:SUN12x22 ${PD}" expand$ to boot-file

\ Uncomment the next 2 lines to see the command line
\   ." cmdline is " boot-file type cr
\   d# 4000 ms

   " ${DN}${PN}\vmlinuz"    expand$ to boot-device
   " ${DN}${PN}\initrd.gz" expand$ to ramdisk
   boot
;
olpc-fth-boot-me

