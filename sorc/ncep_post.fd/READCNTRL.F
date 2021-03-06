!> @file
!
!> SUBPROGRAM:    READCNTRL  READS CONTROL FILE
!!   PRGRMMR: TREADON         ORG: W/NP2      DATE: 92-12-20       
!!     
!! ABSTRACT:
!!     THIS ROUTINE READS THE CONTROL FILE SPECIFYING
!!     DATA FORMAT(S) AND FIELD(S) TO POST.  THE
!!     ORDER OF OPERATIONS IS 
!!        (1) READ HEADER BLOCK OF CONTROL FILE,
!!        (2) SET FLAGS, CLOSE OPEN UNITS
!!        (3) READ BODY OF CONTROL FILE (FIELD SPECIFICATIONS)
!!     
!! PROGRAM HISTORY LOG:
!!   92-12-20  RUSS TREADON
!!   93-06-15  RUSS TREADON - ADD PROJECTION CONTROL CARD
!!   98-06-01  BLACK - CONVERSION OF POST FROM 1-D TO 2-D
!!   98-07-17  MIKE BALDWIN - REMOVED PACK84
!!   01-10-22  H CHUANG - MODIFIED TO PROCESS HYBRID MODEL OUTPUT
!!   02-01-16  MIKE BALDWIN - WRF VERSION
!!   21-03-11  B Cui - change local arrays to dimension (im,jsta:jend)
!!     
!! USAGE:    CALL READCNTRL(IEOF)
!!   INPUT ARGUMENT LIST:
!!     NONE
!!
!!   OUTPUT ARGUMENT LIST: 
!!     IEOF     - INTEGER FLAG FOR EOF IN CONTROL FILE.
!!                IEOF=0 WHEN AN EOF IS READ IN THE
!!                CONTROL FILE.  IEOF=1 OTHERWISE.
!!     
!!   OUTPUT FILES:
!!     NONE
!!     
!!   SUBPROGRAMS CALLED:
!!     UTILITIES:
!!
!!     LIBRARY:
!!       COMMON   - RQSTFLD 
!!                  CTLBLK
!!     
!!   ATTRIBUTES:
!!     LANGUAGE: FORTRAN
!!     MACHINE : CRAY C-90
!!
      SUBROUTINE READCNTRL(kth,IEOF)
!

!
!     
!     INCLUDE ETA GRID DIMENSIONS.  SET/DERIVE PARAMETERS.
!
       use lookup_mod,only: ITB,JTB,ITBQ,JTBQ
       use ctlblk_mod, only: me, ifhr, ihrst, sdat, imdlty, im, jm
       use rqstfld_mod, only: mxfld, iget, kgtype, datset, ritehd, &
              field, dec, lvls, mxlvl, avbl, ident, nfld
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
       implicit none
!
      real,PARAMETER :: DTR=1.745329E-2,RTD=1./DTR
!
!     DECLARE VARIABLES.
!     
      LOGICAL NORTH
      CHARACTER*2  CHAR2
      CHARACTER*4  CHAR4
      CHARACTER*80 LINE
!jw
      integer, intent(in) :: KTH
      integer, intent(inout) :: IEOF
      integer LCNTRL,LUNOUT,ISUM,L,IFLD,IAVBL
!
!******************************************************************************
!     START READCNTRL HERE.
!     

      LCNTRL=14
      LUNOUT=60

      IF(ME==0)THEN
        WRITE(6,*)'READCNTRL:  POSTING FCST HR ',IFHR,' FROM ',         &
             IHRST,'UTC ',SDAT(1),'-',SDAT(2),'-',SDAT(3),' RUN'
      ENDIF
!     
!     INITIALIZE VARIABLES.
!        IEOF IS THE END OF FILE FLAG FOR THE CONTROL FILE.
!        ARRAY IGET IS THE "GET FIELD" FLAG ARRAY.
!
      IEOF=0
      DO 100 IFLD=1,MXFLD
        IGET(IFLD)=-1
 100  CONTINUE
!
      if(me==0)print*,'start reading control file'
!
      READ(LCNTRL,1000,ERR=990,END=999) KGTYPE
      READ(LCNTRL,1000,ERR=990,END=999) IMDLTY
      READ(LCNTRL,1030,ERR=990,END=999) DATSET
 1000 FORMAT(T28,I5)
 1030 FORMAT(T28,A6)
!     
!     SET FLAG TO OPEN NEW OUTPUT FILE
!
      RITEHD = .TRUE.
!     
!     ECHO HEADER INFO TO 6.
!
      IF(ME==0)THEN
        WRITE(6,*)'READCNTRL:  HEADER INFORMATION'
        WRITE(6,*)' KGTYPE       :  ',KGTYPE
        WRITE(6,*)' IMDLTY       :  ',IMDLTY
        WRITE(6,*)' DATSET       :  ',DATSET
        WRITE(6,*)' RITEHD       :  ',RITEHD
      ENDIF
!     
!     NOW READ WHICH FIELDS ON 
!     WHICH LEVELS TO INTERPOLATE TO THE OUTPUT GRID.  THE
!     CHARACTER STRING "DONE" MARKS THE END OF THE OUTPUT
!     FIELD SPECIFICATIONS.
!
      IFLD = 0
 10   CONTINUE
         READ(LCNTRL,1060,ERR=996) LINE
         IF (INDEX(LINE,'DONE')/=0) GOTO 40
         IF (INDEX(LINE,'SCAL=')==0)   GOTO 10
         IFLD        = IFLD+1
         FIELD(IFLD) = LINE(3:22)
         READ(LINE,1061) DEC(IFLD)
         READ(LCNTRL,1090,ERR=996) (LVLS(L,IFLD),L=1,MXLVL)
 1060    FORMAT(A80)
 1061    FORMAT(30X,F4.1)
 1070    FORMAT(A4)
 1080    FORMAT(A2)

#ifdef COMMCODE
 1090    FORMAT(T5,14(5I1,1X))
#else
 1090    FORMAT(T5,100(5I1,1X))
#endif
!     
!        SEE IF WE WANT THIS FIELD.  THE SUM OF THE LEVELS
!        INDICATORS MUST BE GREATER THAN ZERO IF WE WANT 
!        THIS FIELD.
!     
         ISUM = 0
         DO 15 L = 1,MXLVL
            ISUM = ISUM + LVLS(L,IFLD)
 15      CONTINUE
         IF (ISUM<1) THEN
            IFLD = IFLD - 1
            GOTO 10
         ENDIF
!     
!        SEE IF REQUESTED FIELD IS AVAILABLE.  IF NOT, 
!        WRITE MESSAGE TO 6 AND DECREMENT FIELD 
!        COUNTER BY ONE.  THEN READ NEXT REQUESTED FIELD.
!     
         DO 20 IAVBL = 1,MXFLD
            IF (INDEX(FIELD(IFLD),AVBL(IAVBL))/=0)GO TO 30
 20      CONTINUE
         IF(ME==0)THEN
           WRITE(6,*)'FIELD ',FIELD(IFLD),' NOT AVAILABLE'
         ENDIF
         IFLD = IFLD-1
         GOTO 10
!     
!        IF FIELD IS AVAILABLE, TURN THE GET SWITCH ON.
!     
 30      CONTINUE
         IGET(IAVBL) = IFLD
         IDENT(IFLD) = IAVBL
         GOTO 10
!     
!     ALL DONE READING REQUESTED FIELDS FOR CURRENT OUTPUT GRID.
!     SET NFLD TO TOTAL NUMBER OF REQUESTED OUTPUT FIELDS THAT 
!     ARE AVAILABLE.
!
 40   CONTINUE

      NFLD = IFLD
! skip creating ipv files if kth=0 and no isobaric fields are requested in ctl file      


      if(kth==0 .and. iget(013)<=0)go to 999
!     
!     ECHO OUTPUT FIELDS/LEVELS TO 6.
!
      IF(ME==0)THEN
        WRITE(6,*)'BELOW ARE FIELD/LEVEL/SMOOTHING ',       &
             'SPECIFICATIONS.,NFLD=',NFLD,'MXLVL=',MXLVL
      ENDIF
      DO 50 IFLD = 1,NFLD
        IF(ME==0)THEN
         WRITE(6,2060) FIELD(IFLD)
         WRITE(6,2070) (LVLS(L,IFLD),L=1,MXLVL)
 2060    FORMAT('(',A20,')')
 2070    FORMAT('L=(',14(5I1,1X),')')
        ENDIF
 50   CONTINUE
!     
!     WE HAVE AN OUTPUT GRID AND THE FIELDS TO GENERATE ON IT.
!     SKIP OVER THE FOLLOWING EOF MESSAGE TO EXIT THIS ROUTINE.
!     
      GOTO 60
!     
!     WE REACH THIS BLOCK ONLY IF THERE IS AN ERROR WHILE READING
!     IN THE CONTROL FILE.  PRINT AN ERROR MESSAGE TO STANDARD
!     OUT AND CARRY ON.
!     
 990  CONTINUE
      IF(ME==0)THEN
        WRITE(6,*)' READCNTRL:  ERROR READING CNTRL HEADER INFO'
        WRITE(6,*)' BELOW IS CNTRL GRID INFO'
        WRITE(6,*)'  KGTYPE,DATSET:  ',KGTYPE,' ',DATSET
      ENDIF
      GOTO 999
 996  CONTINUE
      IF(ME==0)THEN
        WRITE(6,*)' READCNTRL:  ERROR READING CNTRL FLD/LVL INFO'
      ENDIF
!     
!     WE REACH THIS BLOCK ONLY WHEN AN EOF HAS BEEN READ FROM 
!     THE CONTROL FILE.  THAT MEANS WE'VE PROCESSED ALL GRIDS
!     AND ALL FIELDS.  WE'RE DONE.  SET THE EOF FLAG TO ANY
!     NONZERO INTEGER, SAY ONE.  CLOSE THE UNIT CONNECTED TO
!     THE LAST OUTPUT FILE AND EXIT THE ROUTINE.
!     
 999  CONTINUE
      IEOF=1
      CLOSE(LUNOUT)
      IF(ME==0)THEN
        WRITE(6,*)' READCNTRL:  ALL GRIDS PROCESSED.  ',             &
             'CLOSED ',LUNOUT
      ENDIF
!     
!     END OF ROUTINE.
!     
 60   CONTINUE
      RETURN
      END
