      SUBROUTINE PDCYLM( )
C#######################################################################
C
C PDCYL
C
C This structural weight estimation code was pulled from ACSYNT and then
C wrapped for use in ModelCenter
C
C Work done by: Bill Fredericks starting in Feb 2007
C
C#######################################################################
C2345&*89 123456789 123456789 123456789 123456789 123456789 123456789 12

C############################
C Input Variable Declerations

      CHARACTER*50 AIRCRAFT  ! Aircraft Character String
      INTEGER  ICALC       ! 3 - Print out more in output file

C Wing
C Geometry
      REAL     WSWEEP      ! Wing sweep referenced to the leading edge  (deg)
      REAL     WAR         ! Wing Aspect Ratio
      REAL     WTAPER      ! Wing taper ratio
      REAL     WTCROOT     ! Wing thickness-to-cord at root
      REAL     WTCTIP      ! Wing thickness-to-cord at tip
      REAL     WAREA       ! Wing planform area                         (ft^2)
C Material Properties
      REAL     PS          ! Plasticity factor
      REAL     TMGW        ! Min. gage thickness for the wing           (inches)
      REAL     EFFW        ! Buckling efficiency of the web
      REAL     EFFC        ! Buckling efficiency of the covers
      REAL     ESW         ! Young�s Modulus for wing material          (psi)
      REAL     FCSW        ! Ult. compressive strength of wing          (psi)
      REAL     DSW         ! Density of the wing material               (lb/in^3)
      REAL     KDEW        ! Knock-down factor for Young's Modulus
      REAL     KDFW        ! Knock-down factor for Ultimate strength
C Geometric Parameters
      INTEGER  ISTAMA      ! 1 - Position of wing is unknown
                           ! 2 - position is known
      REAL     CS1         ! Position of structural wing box from leading edge as percent of root chord
      REAL     CS2         ! Position of structural wing box from trailing edge as percent of root chord
      REAL     UWWG        ! Wing Weight / Wing Area of baseline aircraft      (lb/ft^2)
c     REAL     XWLOC1      ! Location of wing as a percentage of body length
C Structural Concept
      REAL     CLAQR       ! Ratio of body lift to wing lift
      INTEGER  IFUEL       ! 1 - No fuel is stored in the wing
                           ! 2 - Fuel is stored in the wing
      REAL     CWMAN       ! Design maneuver load factor
      REAL     CF          ! Shanley's const. for frame bending


C Tails
      INTEGER  ITAIL       ! 1 - Control surfaces mounted on tail
                           ! 2 - Control surfaces mounted on wing
      REAL     UWT         ! (Htail Weight + Vtail Weight) / Htail Area of baseline aircraft      (lb/ft^2)
      REAL     CLRT        ! Location of tail as a percentage of body length
      REAL     HAREA       ! Htail planform area                        (ft^2)


C Fuselage
C Geometry
c     REAL     FRN         ! Fineness ratio of the nose section         (length/diameter)
c     REAL     FRAB        ! Fineness ratio of the after-body section   (length/diameter)
c     REAL     BODL        ! Length of the fuselage                     (ft)
c     REAL     BDMAX       ! Maximum diameter of fuselage               (ft)
      REAL     VBOD        ! Fuselage total volume                      (ft^3)
      REAL     VOLNOSE     ! Nose volume                                (ft^3)
      REAL     VOLTAIL     ! Tail volume                                (ft^3)
C Structural Concept
      REAL     CKF         ! Frame stiffness coefficient
      REAL     EC          ! Power in approximation equation for buckling stability
      REAL     KGC         ! Buckling coefficient for component general buckling of stiffener web panel
      REAL     KGW         ! Buckling coefficient for component local buckling of web panel
c     INTEGER  KCONT(12)   ! Structural Geometry Concept Top/Bottom
c     INTEGER  KCONB(12)   ! 2 - Simply stiffened shell, frames, sized for minimum weight in buckling
                           ! 3 - Z-stiffened shell, frames, best buckling
                           ! 4 - Z-stiffened shell, frames, buckling-minimum gage compromise
                           ! 5 - Z-stiffened shell, frames, buckling-pressure compromise
                           ! 6 - Truss-core sandwich, frames, best buckling
                           ! 8 - Truss-core sandwich, no frames, best buckling
                           ! 9 - Truss-core sandwich, no frames, buckling-min. gage-pressure compromise
C Material Properties
c     REAL     FTST(12)    ! Tensile Strength on top/bottom             (psi)
c     REAL     FTSB(12)
c     REAL     FCST(12)    ! Compressive Strength top/bottom            (psi)
c     REAL     FCSB(12)
c     REAL     EST(12)     ! Young's Modulus for the shells top/bottom  (psi)
c     REAL     ESB(12)
c     REAL     EFT(12)     ! Young's Modulus for the frames top/bottom  (psi)
c     REAL     EFB(12)
c     REAL     DST(12)     ! Density of shell material on top/bottom    (lb/in^3)
c     REAL     DSB(12)
c     REAL     DFT(12)     ! Density of frame material on top/bottom    (lb/in^3)
c     REAL     DFB(12)
c     REAL     TMGT(12)    ! Minimum gage thickness top/bottom          (in)
c     REAL     TMGB(12)
c     REAL     KDE         ! Knock-down factor for modulus
c     REAL     KDF         ! Knock-down factor for strength
C Geometric Parameters
      REAL     CLBR1       ! Fuselage break point as a fraction of total fuselage length
      INTEGER  ICYL        ! 1 - modeled with a mid-body cylinder
                           ! 0 - use two power-law bodies back to back


C Engines
      INTEGER  NENG        ! Total number of engines
      INTEGER  NENGWING    ! Number of engines on wing
      REAL     WFP         ! (Engine Weight * NENG) / WGTO
      REAL     CLRW1       ! Location of first engine pair.  Input 0 for centerline engine.  For wing mounted input as a fraction of semispan,
                           ! measured from body centerline.
      REAL     CLRW2       ! Location of second engine pair.  For wing mounted input as a fraction of semispan, measured from body centerline.
      REAL     CLRW3       ! Location of third engine pair.  For wing mounted input as a fraction of semispan, measured from body centerline.


C Loads
c     REAL     DESLF       ! Design load factor
c     REAL     ULTLF       ! Ultimate load factor (usually 1.5*DESLF)
      REAL     AXAC        ! Axial acceleration                         (g's)
      REAL     CMAN        ! Weight fraction at maneuver
c     INTEGER  ILOAD       ! 1 - Analyze maneuver only
                           ! 2 - Analyze maneuver and landing only
                           ! 3 - Analyze bump, landing and maneuver
c     REAL     PGT(12)     ! Fuselage gage pressure on top/bottom       (psi)
c     REAL     PGB(12)
c     REAL     WFBUMP      ! Weight fraction at bump
c     REAL     WFLAND      ! Weight fraction at landing


C Landing Gear
c     REAL     VSINK       ! Design sink velocity at landing            (ft/sec)
c     REAL     STROKE      ! Stroke of landing gear                     (ft)
      REAL     CLRG1       ! Length fraction of nose landing gear measured as a fraction of total fuselage length
      REAL     CLRG2       ! Length fraction of main landing gear measured as a fraction of total fuselage length
      REAL     WFGR1       ! Weight fraction of nose landing gear
      REAL     WFGR2       ! Weight fraction of main landing gear
      INTEGER  IGEAR       ! 1 - Main landing gear located on fuselage
                           ! 2 - Main landing gear located on wing
c     REAL     GFRL        ! Ratio of force taken by nose landing gear to force taken by main gear at landing
      REAL     CLRGW1      ! Position of wing gear as a fraction of structural semispan
      REAL     CLRGW2      ! Position of second pair wing gear as a fraction of structural semispan
                           ! If only 1 wing gear, set CLBR2 = 0.0


C Weights
c     REAL     WGTO        ! Gross takeoff weight
      REAL     WTFF        ! Weight fraction of fuel
*******************   these 2 varables are duplicated, don't know why    *****************
c     REAL     CBUM        ! Weight fraction at bump
c     REAL     CLAN        ! Weight fraction at landing


C Factors
      INTEGER  ISCHRENK    ! 1 - use Schrenk load distribution on wing
                           ! Else - use trapezoidal distribution
      INTEGER  ICOMND      ! 1 - print gross shell dimensions envelope
                           ! 2 - print detailed shell geometry
      REAL     WGNO        ! Nonoptimal factor for wing (including the secondary structure)
c     REAL     SLFMB       ! Static load factor for bumps
      REAL     WMIS        ! Volume component of secondary structure
      REAL     WSUR        ! Surface area component of secondary structure
      REAL     WCW         ! Factor in weight equation for nonoptimal weights
      REAL     WCA         ! Factor in weight equation multiplying surface areas for nonoptimal weights
      INTEGER  NWING       ! Number of wing segments for analysis


C###############################
C Internal Variable Declerations

      REAL     ENPD, LBOX, LNOSE, LAB
      DIMENSION XFUS(51),DFUS(51)

      INCLUDE 'STRTCM.INC'
      INCLUDE 'VEHICON.INC'
      INCLUDE 'LAND.INC'
      
      COMMON/LOAD  /CG    , CMAN  , WTO   , IFUEL , WBOD  ,
     *              CL    , WWINGT, CGW   , ABOD  , CLW1  , 
     *              CLW2  , POW   , A0M   , CLAQR ,
     *              SPLAN , ATAIL , CLT   , SLFM  , DX    , 
     *              CLP1  , CLP2  , WPROP , WTAIL , B     , 
     *              AVBMM1(60), ABODL , CPB   , RG    , RGB, 
     *              RGW   , CGUST , A0G   , V     , VGU   ,
     *              AVBMG(60) , CX1   , CX2   , AVBML(60) , A0L, 
     *              DTL   , VELL  , Y10   , Y20   , C1    , 
     *              C2    , CLAND , TFL   , ZETA  ,
     *              ITAIL , CGP   , WGEAR , WGEAR1, WGEAR2,
     *              IGEAR , CGG   , CLG1  , CLG2  , CLG   ,
     *              ICYL  , WPROPW, WPROPF, ENPD  , ENWG  ,
     *              VBOD  , VOLNOSE,VOLTAIL,CLRP1 , CLRP2

      COMMON/WWIN1/WINGL, ASPR  , TAPER , ROOTCT, TIPC  , GAML  , 
     *    GAMT  , WGNO  , SPAN  , WTFF  , NWING , TRATW ,  
     1    DSW   , ESW   , FCSW  , FACS  , CLRW1 , CLRW2 ,
     2    CLRW3 , WBOX  , XCLWNG, NBOX1 , NBOX2 , TBOX  , LBOX  , 
     3    WWBOX , EFFC  , EFFW  , TBCOV , NBOX3 , RBMAX , UWWG  , 
     4    XCLWNGR,CS1   , CS2   , EC    , KGC   , KGW   , TMGW  , 
     5    CLPE1 , CLPE2 , CLPE3 , WENG1 , WENG2 , WENG3 , CPW   , 
     6    CLINT , WWGPD , WFUEL , CWMAN , D     ,ISCHRENK,TRATWR,
     7    TRATWT, CLRGW1,CLRGW2 , KDEW  , KDFW  , WFP   , UWT,
     8    XWGLOC

      COMMON/AX1/WSAV(60),STA(60),RB(60),VB(60),AS(60),AP(60),
     *  CPBD(60),CGB

      COMMON/AX/POW1,POW2,CL1,CL2,P111,P112,P121,P122,P211,P212,
     1 P221,P222,DENB,CL1A,CL1B,CL2A,CL2B
     
      COMMON      /CONCEPT/         BRAT,TRAT,ANGLR,MARK,KX

      COMMON /PDCYLCOM/   ICOMND,  CLRG1,  CLRG2,  WFGR1,  WFGR2,
     1    ISTAMA, FR    , PS    ,CF     ,
     2    CLRT  , WFPROP,  CKF  ,  WCW  ,  WCA  ,
     5    AXAC  , ART   ,CLBR1  ,  WMIS  , WSUR , PHI

      COMMON /OUTPUTS/  WEBSB, TORK, WSHEAR, WBEND, WSHBOX, WBDBOX,
     1  WTOBOX, DELTIP, CNTRLA, CTST, WNOP, WNOPS, WSEC

C########################################
C Read Input File and Echo to output file

      OPEN(1,FILE='PDCYL.in')
      OPEN(2,FILE='PDCYL.out')

      READ(1,*)
      WRITE(2,*)'PDCYL Output File'
      READ(1,*)
      WRITE(2,*)
      READ(1,'(a50)')AIRCRAFT
      WRITE(2,*)AIRCRAFT
      READ(1,*)
      WRITE(2,*)      
      READ(1,*)ICALC
      WRITE(2,200)ICALC,' ICALC     '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)'Wing'
      READ(1,*)
      WRITE(2,*)'Geometry'
      READ(1,*)WSWEEP
      WRITE(2,100)WSWEEP,' WSWEEP    '
      READ(1,*)WAR
      WRITE(2,100)WAR,' WAR       '
      READ(1,*)WTAPER
      WRITE(2,100)WTAPER,' WTAPER    '
      READ(1,*)WTCROOT
      WRITE(2,100)WTCROOT,' WTCROOT   '
      READ(1,*)WTCTIP
      WRITE(2,100)WTCTIP,' WTCTIP    '
      READ(1,*)WAREA
      WRITE(2,100)WAREA,' WAREA     '
      READ(1,*)
      WRITE(2,*)'Material Properties'
      READ(1,*)PS
      WRITE(2,100)PS,' PS        '
      READ(1,*)TMGW
      WRITE(2,100)TMGW,' TMGW      '
      READ(1,*)EFFW
      WRITE(2,100)EFFW,' EFFW      '
      READ(1,*)EFFC
      WRITE(2,100)EFFC,' EFFC      '
      READ(1,*)ESW
      WRITE(2,300)ESW,' ESW       '
      READ(1,*)FCSW
      WRITE(2,100)FCSW,' FCSW      '
      READ(1,*)DSW
      WRITE(2,100)DSW,' DSW       '
      READ(1,*)KDEW
      WRITE(2,100)KDEW,' KDEW      '
      READ(1,*)KDFW
      WRITE(2,100)KDFW,' KDFW      '
      READ(1,*)
      WRITE(2,*)'Geometric Parameters'
      READ(1,*)ISTAMA
      WRITE(2,200)ISTAMA,' ISTAMA    '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)CS1
      WRITE(2,100)CS1,' CS1       '
      READ(1,*)CS2
      WRITE(2,100)CS2,' CS2       '
      READ(1,*)UWWG
      WRITE(2,100)UWWG,' UWWG      '
      READ(1,*)XWLOC1
      WRITE(2,100)XWLOC1,' XWLOC1    '
      READ(1,*)
      WRITE(2,*)'Structural Concept'
      READ(1,*)CLAQR
      WRITE(2,100)CLAQR,' CLAQR     '
      READ(1,*)IFUEL
      WRITE(2,200)IFUEL,' IFUEL     '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)CWMAN
      WRITE(2,100)CWMAN,' CWMAN     '
      READ(1,*)CF
      WRITE(2,300)CF,' CF        '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)'Tails'
      READ(1,*)ITAIL
      WRITE(2,200)ITAIL,' ITAIL     '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)UWT
      WRITE(2,100)UWT,' UWT       '
      READ(1,*)CLRT
      WRITE(2,100)CLRT,' CLRT      '
      READ(1,*)HAREA
      WRITE(2,100)HAREA,' HAREA     '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)'Fuselage'
      READ(1,*)
      WRITE(2,*)'Geometry'
      READ(1,*)FRN
      WRITE(2,100)FRN,' FRN       '
      READ(1,*)FRAB
      WRITE(2,100)FRAB,' FRAB      '
      READ(1,*)BODL
      WRITE(2,100)BODL,' BODL      '
      READ(1,*)BDMAX
      WRITE(2,100)BDMAX,' BDMAX     '
      READ(1,*)
      WRITE(2,*)'Structural Concept'
      READ(1,*)CKF
      WRITE(2,100)CKF,' CKF       '
      READ(1,*)EC
      WRITE(2,100)EC,' EC        '
      READ(1,*)KGC
      WRITE(2,100)KGC,' KGC       '
      READ(1,*)KGW
      WRITE(2,100)KGW,' KGW       '
      READ(1,*)KCONT(1)
      WRITE(2,200)KCONT(1),' KCONT(1)  '
      READ(1,*)KCONB(1)
      WRITE(2,200)KCONB(1),' KCONB(1)  '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)'Material Properties'
      READ(1,*)FTST(1)
      WRITE(2,300)FTST(1),' FTST(1)   '
      READ(1,*)FTSB(1)
      WRITE(2,300)FTSB(1),' FTSB(1)   '
      READ(1,*)FCST(1)
      WRITE(2,300)FCST(1),' FCST(1)   '
      READ(1,*)FCSB(1)
      WRITE(2,300)FCSB(1),' FCSB(1)   '
      READ(1,*)EST(1)
      WRITE(2,300)EST(1),' EST(1)    '
      READ(1,*)ESB(1)
      WRITE(2,300)ESB(1),' ESB(1)    '
      READ(1,*)EFT(1)
      WRITE(2,300)EFT(1),' EFT(1)    '
      READ(1,*)EFB(1)
      WRITE(2,300)EFB(1),' EFB(1)    '
      READ(1,*)DST(1)
      WRITE(2,100)DST(1),' DST(1)    '
      READ(1,*)DSB(1)
      WRITE(2,100)DSB(1),' DSB(1)    '
      READ(1,*)DFT(1)
      WRITE(2,100)DFT(1),' DFT(1)    '
      READ(1,*)DFB(1)
      WRITE(2,100)DFB(1),' DFB(1)    '
      READ(1,*)TMGT(1)
      WRITE(2,100)TMGT(1),' TMGT(1)   '
      READ(1,*)TMGB(1)
      WRITE(2,100)TMGB(1),' TMGB(1)   '
      READ(1,*)KDE
      WRITE(2,100)KDE,' KDE       '
      READ(1,*)KDF
      WRITE(2,100)KDF,' KDF       '
      READ(1,*)
      WRITE(2,*)'Geometric Parameters'
      READ(1,*)CLBR1
      WRITE(2,100)CLBR1,' CLBR1     '
      READ(1,*)ICYL
      WRITE(2,200)ICYL,' ICYL      '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)'Engines'
      READ(1,*)NENG
      WRITE(2,200)NENG,' NENG      '
      READ(1,*)NENGWING
      WRITE(2,200)NENGWING,' NENGWING  '
      READ(1,*)WFP
      WRITE(2,100)WFP,' WFP       '
      READ(1,*)CLRW1
      WRITE(2,100)CLRW1,' CLRW1     '
      READ(1,*)
      WRITE(2,100)
      READ(1,*)CLRW2
      WRITE(2,100)CLRW2,' CLRW2     '
      READ(1,*)CLRW3
      WRITE(2,100)CLRW3,' CLRW3     '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)'Loads'
      READ(1,*)DESLF
      WRITE(2,100)DESLF,' DESLF     '
      READ(1,*)ULTLF
      WRITE(2,100)ULTLF,' ULTLF     '
      READ(1,*)AXAC
      WRITE(2,100)AXAC,' AXAC      '
      READ(1,*)CMAN
      WRITE(2,100)CMAN,' CMAN      '
      READ(1,*)ILOAD
      WRITE(2,200)ILOAD,' ILOAD     '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)PGT(1)
      WRITE(2,100)PGT(1),' PGT(1)    '
      READ(1,*)PGB(1)
      WRITE(2,100)PGB(1),' PGB(1)    '
      READ(1,*)WFBUMP
      WRITE(2,100)WFBUMP,' WFBUMP    '
      READ(1,*)WFLAND
      WRITE(2,100)WFLAND,' WFLAND    '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)'Landing Gear'
      READ(1,*)VSINK
      WRITE(2,100)VSINK,' VSINK     '
      READ(1,*)STROKE
      WRITE(2,100)STROKE,' STROKE    '
      READ(1,*)CLRG1
      WRITE(2,100)CLRG1,' CLRG1     '
      READ(1,*)CLRG2
      WRITE(2,100)CLRG2,' CLRG2     '
      READ(1,*)WFGR1
      WRITE(2,100)WFGR1,' WFGR1     '
      READ(1,*)WFGR2
      WRITE(2,100)WFGR2,' WFGR2     '
      READ(1,*)IGEAR
      WRITE(2,200)IGEAR,' IGEAR     '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)GFRL
      WRITE(2,100)GFRL,' GFRL      '
      READ(1,*)CLRGW1
      WRITE(2,100)CLRGW1,' CLRGW1    '
      READ(1,*)CLRGW2
      WRITE(2,100)CLRGW2,' CLRGW2    '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)'Weights'
      READ(1,*)WGTO
      WRITE(2,100)WGTO,' WGTO      '
      READ(1,*)WTFF
      WRITE(2,100)WTFF,' WTFF      '
      READ(1,*)CBUM
      WRITE(2,100)CBUM,' CBUM      '
      READ(1,*)CLAN
      WRITE(2,100)CLAN,' CLAN      '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)
      READ(1,*)
      WRITE(2,*)'Factors'
      READ(1,*)ISCHRENK
      WRITE(2,200)ISCHRENK,' ISCHRENK  '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)ICOMND
      WRITE(2,200)ICOMND,' ICOMND    '
      READ(1,*)
      WRITE(2,*)
      READ(1,*)WGNO
      WRITE(2,100)WGNO,' WGNO      '
      READ(1,*)SLFMB
      WRITE(2,100)SLFMB,' SLFMB     '
      READ(1,*)WMIS
      WRITE(2,100)WMIS,' WMIS      '
      READ(1,*)WSUR
      WRITE(2,100)WSUR,' WSUR      '
      READ(1,*)WCW
      WRITE(2,100)WCW,' WCW       '
      READ(1,*)WCA
      WRITE(2,100)WCA,' WCA       '
      READ(1,*)NWING
      WRITE(2,200)NWING,' NWING     '
      WRITE(2,*)
c     write(*,*)'Done reading input file!'
      CLOSE(1)
      
      WRITE(2,*)
      WRITE(2,*)'Above this line may be used as the input file.'
      WRITE(2,*)
      WRITE(2,*)'PDCYL Outputs'
      WRITE(2,*)



C#####################
C Variable Translating

      ENPD = NENG
      SLFM = DESLF
      ART = HAREA/WAREA
      FACS = ULTLF/DESLF
      WINGL = WGTO/WAREA
      ASPR = WAR
      WTO = WGTO
      TRATW = (WTCTIP+WTCROOT)/2
      CL = BODL
      B = BDMAX
      CL1 = BODL/2.
      CL1A = FRN*BDMAX
      CL1B = BODL - FRAB*BDMAX
      CL2A = CL - CL1A
      CL2B = CL - CL1B
      ROOTCT = 2*((WAR*WAREA)**.5/WAR)/(1+WTAPER)
      ROOTWG = ROOTCT
      TIPC = ROOTWG*WTAPER
      SPAN = (WAR*WAREA)**.5
      SWG = WAREA
      SPLAN = SWG
      TRWG = WTAPER
      TAPER = TRWG
      TCRWG = WTCROOT
      TRATWR = TCRWG
      TCTWG = WTCTIP
      TRATWT = TCTWG
      ENWG = NENGWING
      XCLWNG = XWLOC1*CL
      XWING = XWLOC1
C      CG = XCG
      GAML = WSWEEP
      KCONT(2) = KCONT(1)
      KCONT(3) = KCONT(1)
      KCONT(4) = KCONT(1)
      KCONT(5) = KCONT(1)
      KCONT(6) = KCONT(1)
      KCONT(7) = KCONT(1)
      KCONT(8) = KCONT(1)
      KCONT(9) = KCONT(1)
      KCONT(10) = KCONT(1)
      KCONT(11) = KCONT(1)
      KCONT(12) = KCONT(1)
      KCONB(2) = KCONB(1)
      KCONB(3) = KCONB(1)
      KCONB(4) = KCONB(1)
      KCONB(5) = KCONB(1)
      KCONB(6) = KCONB(1)
      KCONB(7) = KCONB(1)
      KCONB(8) = KCONB(1)
      KCONB(9) = KCONB(1)
      KCONB(10) = KCONB(1)
      KCONB(11) = KCONB(1)
      KCONB(12) = KCONB(1)
      FTST(2) = FTST(1)
      FTST(3) = FTST(1)
      FTST(4) = FTST(1)
      FTST(5) = FTST(1)
      FTST(6) = FTST(1)
      FTST(7) = FTST(1)
      FTST(8) = FTST(1)
      FTST(9) = FTST(1)
      FTST(10) = FTST(1)
      FTST(11) = FTST(1)
      FTST(12) = FTST(1)
      FTSB(2) = FTSB(1)
      FTSB(3) = FTSB(1)
      FTSB(4) = FTSB(1)
      FTSB(5) = FTSB(1)
      FTSB(6) = FTSB(1)
      FTSB(7) = FTSB(1)
      FTSB(8) = FTSB(1)
      FTSB(9) = FTSB(1)
      FTSB(10) = FTSB(1)
      FTSB(11) = FTSB(1)
      FTSB(12) = FTSB(1)
      FCST(2) = FCST(1)
      FCST(3) = FCST(1)
      FCST(4) = FCST(1)
      FCST(5) = FCST(1)
      FCST(6) = FCST(1)
      FCST(7) = FCST(1)
      FCST(8) = FCST(1)
      FCST(9) = FCST(1)
      FCST(10) = FCST(1)
      FCST(11) = FCST(1)
      FCST(12) = FCST(1)
      FCSB(2) = FCSB(1)
      FCSB(3) = FCSB(1)
      FCSB(4) = FCSB(1)
      FCSB(5) = FCSB(1)
      FCSB(6) = FCSB(1)
      FCSB(7) = FCSB(1)
      FCSB(8) = FCSB(1)
      FCSB(9) = FCSB(1)
      FCSB(10) = FCSB(1)
      FCSB(11) = FCSB(1)
      FCSB(12) = FCSB(1)
      EST(2) = EST(1)
      EST(3) = EST(1)
      EST(4) = EST(1)
      EST(5) = EST(1)
      EST(6) = EST(1)
      EST(7) = EST(1)
      EST(8) = EST(1)
      EST(9) = EST(1)
      EST(10) = EST(1)
      EST(11) = EST(1)
      EST(12) = KCONT(1)
      ESB(2) = ESB(1)
      ESB(3) = ESB(1)
      ESB(4) = ESB(1)
      ESB(5) = ESB(1)
      ESB(6) = ESB(1)
      ESB(7) = ESB(1)
      ESB(8) = ESB(1)
      ESB(9) = ESB(1)
      ESB(10) = ESB(1)
      ESB(11) = ESB(1)
      ESB(12) = ESB(1)
      EFT(2) = EFT(1)
      EFT(3) = EFT(1)
      EFT(4) = EFT(1)
      EFT(5) = EFT(1)
      EFT(6) = EFT(1)
      EFT(7) = EFT(1)
      EFT(8) = EFT(1)
      EFT(9) = EFT(1)
      EFT(10) = EFT(1)
      EFT(11) = EFT(1)
      EFT(12) = EFT(1)
      EFB(2) = EFB(1)
      EFB(3) = EFB(1)
      EFB(4) = EFB(1)
      EFB(5) = EFB(1)
      EFB(6) = EFB(1)
      EFB(7) = EFB(1)
      EFB(8) = EFB(1)
      EFB(9) = EFB(1)
      EFB(10) = EFB(1)
      EFB(11) = EFB(1)
      EFB(12) = EFB(1)
      DST(2) = DST(1)
      DST(3) = DST(1)
      DST(4) = DST(1)
      DST(5) = DST(1)
      DST(6) = DST(1)
      DST(7) = DST(1)
      DST(8) = DST(1)
      DST(9) = DST(1)
      DST(10) = DST(1)
      DST(11) = DST(1)
      DST(12) = DST(1)
      DSB(2) = DSB(1)
      DSB(3) = DSB(1)
      DSB(4) = DSB(1)
      DSB(5) = DSB(1)
      DSB(6) = DSB(1)
      DSB(7) = DSB(1)
      DSB(8) = DSB(1)
      DSB(9) = DSB(1)
      DSB(10) = DSB(1)
      DSB(11) = DSB(1)
      DSB(12) = DSB(1)
      DFT(2) = DFT(1)
      DFT(3) = DFT(1)
      DFT(4) = DFT(1)
      DFT(5) = DFT(1)
      DFT(6) = DFT(1)
      DFT(7) = DFT(1)
      DFT(8) = DFT(1)
      DFT(9) = DFT(1)
      DFT(10) = DFT(1)
      DFT(11) = DFT(1)
      DFT(12) = DFT(1)
      DFB(2) = DFB(1)
      DFB(3) = DFB(1)
      DFB(4) = DFB(1)
      DFB(5) = DFB(1)
      DFB(6) = DFB(1)
      DFB(7) = DFB(1)
      DFB(8) = DFB(1)
      DFB(9) = DFB(1)
      DFB(10) = DFB(1)
      DFB(11) = DFB(1)
      DFB(12) = DFB(1)
      TMGT(2) = TMGT(1)
      TMGT(3) = TMGT(1)
      TMGT(4) = TMGT(1)
      TMGT(5) = TMGT(1)
      TMGT(6) = TMGT(1)
      TMGT(7) = TMGT(1)
      TMGT(8) = TMGT(1)
      TMGT(9) = TMGT(1)
      TMGT(10) = TMGT(1)
      TMGT(11) = TMGT(1)
      TMGT(12) = TMGT(1)
      TMGB(2) = TMGB(1)
      TMGB(3) = TMGB(1)
      TMGB(4) = TMGB(1)
      TMGB(5) = TMGB(1)
      TMGB(6) = TMGB(1)
      TMGB(7) = TMGB(1)
      TMGB(8) = TMGB(1)
      TMGB(9) = TMGB(1)
      TMGB(10) = TMGB(1)
      TMGB(11) = TMGB(1)
      TMGB(12) = TMGB(1)
      PGT(2) = PGT(1)
      PGT(3) = PGT(1)
      PGT(4) = PGT(1)
      PGT(5) = PGT(1)
      PGT(6) = PGT(1)
      PGT(7) = PGT(1)
      PGT(8) = PGT(1)
      PGT(9) = PGT(1)
      PGT(10) = PGT(1)
      PGT(11) = PGT(1)
      PGT(12) = PGT(1)
      PGB(2) = PGB(1)
      PGB(3) = PGB(1)
      PGB(4) = PGB(1)
      PGB(5) = PGB(1)
      PGB(6) = PGB(1)
      PGB(7) = PGB(1)
      PGB(8) = PGB(1)
      PGB(9) = PGB(1)
      PGB(10) = PGB(1)
      PGB(11) = PGB(1)
      PGB(12) = PGB(1)

      LNOSE = FRN*BDMAX
      LAB = FRAB*BDMAX

      CALL BODY(LNOSE,LAB,BODL,BDMAX,XFUS,DFUS)
      CALL AVOL(XFUS,DFUS,51,VBOD,VOLNOSE,VOLTAIL)
      CALL PDCEX(ICALC)


C  The fuel weight wasn't subtracted from the wing weight
      IF ( IFUEL .EQ. 2 ) THEN
        WWINGT = WWINGT - WFUEL
      ENDIF


C####################
C Write Major Outputs

C      WRITE(2,*)
C      WRITE(2,*)
C      WRITE(2,*)'Major Outputs'
C      WRITE(2,*)
C      WRITE(2,100)WEBSB, ' WEBSB     '
C      WRITE(2,100)TBCOV, ' TBCOV     '
C      WRITE(2,300)TORK,  ' TORK      '
C      WRITE(2,100)LBOX,  ' LBOX      '
C      WRITE(2,100)WBOX,  ' WBOX      '
C      WRITE(2,100)TBOX,  ' TBOX      '
C      WRITE(2,100)WSHEAR,' WSHEAR    '
C      WRITE(2,100)WBEND, ' WBEND     '
CC      WRITE(2,*)WSWING,  ' WSWING    ' ! Why is this not used? WJF
C      WRITE(2,100)WSHBOX,' WSHBOX    '
C      WRITE(2,100)WBDBOX,' WBDBOX    '
C      WRITE(2,100)WTOBOX,' WTOBOX    '
C      WRITE(2,100)WWBOX, ' WWBOX     '
C      WRITE(2,100)WWINGT,' WWINGT    '
C      WRITE(2,100)WFUEL, ' WFUEL     '
C      WRITE(2,100)DELTIP,' DELTIP    '
C      WRITE(2,100)CNTRLA,' CNTRLA    '
C      WRITE(2,100)CTST,  ' CTST      '
CC      WRITE(2,*)WSFUS,   ' WSFUS     ' ! Why is this not used? WJF
CC      WRITE(2,*)WSFUSS,  ' WSFUSS    '
CC      WRITE(2,*)WSFFR,   ' WSFFR     '
CC      WRITE(2,*)WSFFRS,  ' WSFFRS    '
C      WRITE(2,100)WNOP,  ' WNOP      '
C      WRITE(2,100)WNOPS, ' WNOPS     '
C      WRITE(2,100)WSEC,  ' WSEC      '
CC      WRITE(2,*)WBDS,    ' WBDS      '


      CLOSE(2)
  100 FORMAT(3X,F12.4,A12)
  200 FORMAT(3X,I12,A12)
  300 FORMAT(3X,E12.4,A12)

C     STOP
      RETURN
      END