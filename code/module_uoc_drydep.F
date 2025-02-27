MODULE module_uoc_drydep
!----------------------------------------------------------------
! calculating dust dry deposition velocity and flux
! according to zhang(2014),
! the scheme is developed based on drag partition.
!----------------------------------------------------------------
CONTAINS

SUBROUTINE uoc_drydep_driver(dt,                                           &
                             config_flags,numgas,                          &
                             t_phy,moist,                                  &!p8w,t8w,
                             rmol,                                         &
                             p_phy,chem,rho_phy,dz8w,ddvel,xland,hfx,      &
                             ivgtyp,                                       & !tsk,
                             vegfra,pbl,ust,znt,                           & !xlat,xlong,     &
                             exch_h,                                       & !psim,psip,
                             u_phy,v_phy,w_phy,nba_mij,n_nba_mij,          &
                             dustdrydep_1,dustdrydep_2,dustdrydep_3,       &
                             dustdrydep_4,dustdrydep_5,                    &
                             depvel_1,depvel_2,depvel_3,depvel_4,depvel_5, &
                             vel_surf_1, vel_surf_2, vel_surf_3,           &
                             vel_surf_4, vel_surf_5,                       &
                             ids,ide,jds,jde,kds,kde,                      &
                             ims,ime,jms,jme,kms,kme,                      &
                             its,ite,jts,jte,kts,kte                       )
  USE module_model_constants, ONLY:g,mwdry
  USE module_configure
  USE module_state_description
  USE module_data_gocart_dust

  IMPLICIT NONE

  TYPE(grid_config_rec_type), INTENT(IN) :: config_flags
  INTEGER, INTENT( IN ) :: ids,ide,jds,jde,kds,kde,                        &
                           ims,ime,jms,jme,kms,kme,                        &
                           its,ite,jts,jte,kts,kte,                        &
                           numgas
  REAL, INTENT( IN ) :: dt
  REAL, DIMENSION( ims:ime, kms:kme, jms:jme, num_moist ),                 &
        INTENT( IN ) ::                                     moist
  REAL, DIMENSION( ims:ime, kms:kme, jms:jme, num_chem ),                  &
        INTENT( INOUT ) ::                                   chem
  REAL, DIMENSION( ims:ime, kms:kme, jms:jme ),                            &
        INTENT( IN ) ::                                    rho_phy,        &
                                                           p_phy,          &
                                                           t_phy,          &
                                                    u_phy,v_phy,w_phy,     &
                                                           dz8w,           &
                                                           exch_h
  INTEGER, INTENT( IN ) ::                                 n_nba_mij
  REAL, DIMENSION( ims:ime, kms:kme, jms:jme, n_nba_mij ),                 &
        INTENT( IN ) ::                                    nba_mij
  REAL, DIMENSION( its:ite, jts:jte, num_chem ),                           &
        INTENT( INOUT ) ::                                 ddvel

  INTEGER, DIMENSION( ims:ime, jms:jme ),                                  &
        INTENT( IN ) ::                                    ivgtyp
  REAL, DIMENSION( ims:ime, jms:jme ), INTENT(IN) ::                       &
                                                           xland,          &
                                                           vegfra,         &
                                                           pbl,            &
                                                        rmol,znt,ust,hfx
                                                        !,psim,psip
  REAL, DIMENSION( ims:ime, jms:jme ), INTENT( INOUT ) ::                  &
                            dustdrydep_1, dustdrydep_2, dustdrydep_3,      &
                            dustdrydep_4,dustdrydep_5
  REAL, DIMENSION( ims:ime, jms:jme ),INTENT( INOUT ) ::                   &
                                        depvel_1, depvel_2, depvel_3,      &
                                                   depvel_4,depvel_5,      &
                                        vel_surf_1,vel_surf_2,vel_surf_3,  &
                                        vel_surf_4,vel_surf_5
!  REAL, DIMENSION(kts:kte) :: kt_turb
! ..LOCAL SCALARS..

  integer, parameter :: nmx = 5
  integer :: i,j,k,kk,nn,nv,imx,jmx,lmx,ivgt(1,1),rough_flag
  real*8  :: tau
  real*8,dimension(1,1) :: aden, delz, tmp, p_mid, u, v, w,                 &!,psi_zh,psi_z0
                           ustar_f, z0, uu, m13, m23, kturb,         &
                           ust_t,ustar_sg,hflux
  real*8 :: vel_surf(1,1,5),vert_vel(1,1,5)!,cf(1,1)
  !particle radium: (7.3e-7,1.4e-6,2.4e-6,4.5e-6,8e-6)
!
! here its=1,ite=200,ids=1,ide=201
  lmx = kte-kts+1          !lmx=60,kte=60,kts=1
  do nn = 1,nmx
     vel_surf(1,1,nn) = 0.
     if (nn==1) den_dust(nn)=2650.
  enddo

  DO J = jts,jte
  DO I = its,ite

     ivgt(1,1) = ivgtyp(i,j)
     aden(1,1) = rho_phy(i,kts,j)

     kturb(1,1) = max(exch_h(i,kts,j),1.e-6)
     delz(1,1) = dz8w(i,kts,j)
     tmp(1,1)=t_phy(i,kts,j)
     p_mid(1,1)=.01*p_phy(i,kts,j)

!     u(1,1) = u_phy(i,kts,j)
!     v(1,1) = v_phy(i,kts,j)
!     w(1,1) = w_phy(i,kts,j)
!     uu(1,1) = sqrt(u_phy(i,kts,j)**2+v_phy(i,kts,j)**2)
!     m13(1,1) = nba_mij(i,kts,j,p_m13)
!     m23(1,1) = nba_mij(i,kts,j,p_m23)
     hflux(1,1) = real(hfx(i,j),kind=8)
     ustar_sg(1,1) = ust(i,j)
     z0(1,1) = real( znt(i,j),kind = 8 )

     call depvel_uoc(dt,vert_vel,vel_surf,den_dust,reff_dust,aden,kturb,tmp,p_mid,    &
              1,1,lmx,nmx,ivgt,delz,rough_flag,ustar_sg,g,z0,hflux,rmol(i,j))!,psi_zh,psi_z0)

     do nv = p_dust_1,p_dust_5
        ddvel(i,j,nv) = real( vert_vel(1,1,nv-1),kind=4 )
     enddo

     dustdrydep_1(i,j) = -chem(i,1,j,p_dust_1)*vert_vel(1,1,1)*aden(1,1) !here dvel looks normal
     dustdrydep_2(i,j) = -chem(i,1,j,p_dust_2)*vert_vel(1,1,2)*aden(1,1)
     dustdrydep_3(i,j) = -chem(i,1,j,p_dust_3)*vert_vel(1,1,3)*aden(1,1)
     dustdrydep_4(i,j) = -chem(i,1,j,p_dust_4)*vert_vel(1,1,4)*aden(1,1)
     dustdrydep_5(i,j) = -chem(i,1,j,p_dust_5)*vert_vel(1,1,5)*aden(1,1)

     depvel_1(i,j) = vert_vel(1,1,1)!dvel(1,1,1)   ! diffusion speed
     depvel_2(i,j) = vert_vel(1,1,2)!dvel(1,1,2)
     depvel_3(i,j) = vert_vel(1,1,3)!dvel(1,1,3)
     depvel_4(i,j) = vert_vel(1,1,4)!dvel(1,1,4)
     depvel_5(i,j) = vert_vel(1,1,5)!dvel(1,1,5)

     vel_surf_1(i,j) = vel_surf(1,1,1)
     vel_surf_2(i,j) = vel_surf(1,1,2)
     vel_surf_3(i,j) = vel_surf(1,1,3)
     vel_surf_4(i,j) = vel_surf(1,1,4)
     vel_surf_5(i,j) = vel_surf(1,1,5)

  ENDDO
  ENDDO
  END SUBROUTINE uoc_drydep_driver

  subroutine depvel_uoc( dt,vert_vel,vel_surf,dden,reff,aden,kturb,tmp,p_mid,       &
                imx,jmx,lmx,nmx,ivgt,delz,rough_flag,ustar,g0,z0,hflux,rmol)!,  &
              !  psi_zh,psi_z0)
  implicit none

  integer, intent(in) :: imx,jmx,lmx,nmx,rough_flag,ivgt(imx,jmx)
  real*8,  intent(inout) :: vert_vel(imx,jmx,nmx),vel_surf(imx,jmx,nmx)
  real*8,  intent(in) :: dden(nmx),reff(nmx),aden(imx,jmx),kturb(imx,jmx)
  real,    intent(in) :: g0,dt,rmol
  real*8,  intent(in) :: delz(imx,jmx),ustar(imx,jmx),z0(imx,jmx)
                        !ustar_sg(imx,jmx)!,psi_zh(imx,jmx),psi_z0(imx,jmx)
  real*8,  intent(in) :: tmp(imx,jmx),p_mid(imx,jmx),hflux(imx,jmx)
! local scalars
  real*8 :: vd,rg,ra,rs,vd1,vd2,rs2
  real*8 :: c_stokes, free_path, c_cun, viscosity,visk,kp
  integer :: ain
  real*8 :: lame,r,sc,st,sct,miu,rct,uh,EB,Eim,Ein,E, Re
  real*8 :: vt,tp,tp2,cz,wm,uzr
  real*8 :: dc,b,b1,c1,cb,nb,beta,zh,zd,lamda,sbly,zr
  real*8 :: obk,xzz,xzh,xzr,xz0,zolzz,zolzh,zolzr,zolz0,psizz,psizh,psiz0,psizr,dpsi,dpsi_1,dpsi_2,dpsi_3
  real*8,parameter :: kbo=1.38D-23, pi=3.1415927,Cd=0.3
  integer :: kk,nn,i,j
! calculate gravity settling velocity for each layer--------

  j_loop: DO j = 1, jmx
  i_loop: DO i = 1, imx
     ra = 0.
     rg = 0.
     rs = 0.
!--------------------------------
! Land-use categories
!--------------------------------
     if( ivgt(i,j)==12 ) then   !as vegtation can be divided into multi layers, so the surface is assumed as  sticky surface
        Ain = 1.
         dc = 0.                !roughness length diameter
          b = 0.01                 !rebound coefficient
         zh = 0.
         zd = 0.
      lamda = 0.
     elseif( ivgt(i,j)==16 ) then     !water
        Ain = 100.
         dc = 0.1e-3
          b = 0.
         zh = 30.*z0(i,j)
         zd = 0.
        lamda = 0.538
     elseif( ivgt(i,j) == 19 ) then     !sand
        Ain = 1.
         zd = 0
          b = 1.
      lamda = 0.125
         zh = 0.1e-3
     else
        call wrf_message('UoC drydep: specify the landuse first')
     endif

      c_stokes =  1.458E-6*tmp(i,j)**1.5/(tmp(i,j) + 110.4)   ! Dynamic viscosity as a func of temp
      visk=c_stokes/aden(i,j)
      free_path = 1.1E-3/p_mid(i,j)/SQRT(tmp(i,j))           ! Free path as func of pres(mb) and temp(K)

! effective frontal area index
      miu = dc/zh*lamda
      lame = lamda*EXP(-6.*lamda/(1.-miu)**0.1)/(1.-miu)**0.1
      rct = 200.*lame/(1.+200.*lame)    ! tau_c/tau

      cz = delz(i,j)/2.
      sbly = 5.*visk/ustar(i,j)

! ***********************************************************************
! *  Compute the Monin-Obukhov length                                   *
! *  The direct computation of the Monin-Obuhhov length is:             *
! *          -Air density * Cp * T(surface air) * Ustar^3               *
! *  OBK = -------------------------------------------------            *
! *                  vK * g * Sensible Heat flux                        *
! *                                                                     *
! *   Cp = 1000 J/kg/K   = specific heat at constant pressure           *
! *   vK = 0.4           = von Karman's constant                        *
! *
! *
! ***********************************************************************
!      print*,"hflux(i,j) = ",hflux(i,j)
!      IF ( abs(hflux(i,j)) <= 1.e-5_8) THEN
!          obk = 1.0E5
!      ELSE
!          obk =  -airden(i,j) * 1000.0_8 * ts(i,j) * (ustar(i,j))**3 &
!                / (vk * real(g0,kind=8) * hflux(i,j))
!          IF ( obk == 0.0_8 ) WRITE(*,211) obk, i, j
!211       FORMAT(1X, 'OBK=', E11.2, 1X, ' i,j = ', 2I4)
!      END IF
      zr = 2.*zh
      dpsi = 0.
      dpsi_1 = 0.
      dpsi_2 = 0.
      dpsi_3 = 0.
      IF (rmol .ne. 0.) THEN
!      IF (abs(hflux(i,j)) <= 1.e-5_8) THEN
          obk = 1._8/real(rmol, kind = 8)
      ELSE
         ! obk = 1.e5_8
          GOTO 300
      ENDIF
      zolzz = cz / obk
      zolz0 = z0(i,j) / obk
      zolzh = (zh+sbly) / obk
      zolzr = zr / obk
      IF ( zolzz > 0._8 ) THEN   ! stable
          psizz = -5._8 * zolzz
          psizh = -5._8 * zolzh
          psiz0 = -5._8 * zolz0
          psizr = -5._8 * zolzr
      ELSE IF ( zolzz < 0._8 ) THEN                    ! unstable
          xzz = (1.0 - 15.0*zolzz)**0.25
          psizz = 2.0 * log( (1.0+xzz)/2.0 ) + log( (1.0+xzz**2.0)/2.0 ) &
             - 2.0*atan(xzz) + pi/2.0

          xzh = (1.0 - 15.0*zolzh)**0.25
          psizh = 2.0 * log( (1.0+xzh)/2.0 ) + log ( (1.0+xzh**2.0)/2.0) &
             -2.0 *atan(xzh) + pi /2.0

          xz0 = (1.0 - 15.0*zolz0)**0.25
          psiz0 = 2.0 * log( (1.0+xz0)/2.0 ) + log ( (1.0+xz0**2.0)/2.0) &
             -2.0 *atan(xz0) + pi /2.0

          xzr = (1.0 - 15.0*zolzr)**0.25
          psizr = 2.0 * log( (1.0+xzr)/2.0 ) + log ( (1.0+xzr**2.0)/2.0) &
             -2.0 *atan(xzr) + pi /2.0
      END IF
      dpsi = psizz - psizh
      dpsi_1 = psizh - psiz0
      dpsi_2 = psizz - psiz0
      dpsi_3 = psizr - psiz0
      print*,"obk,zolzz,zolzh,zolz0",obk,zolzz,zolzh,zolz0
      print*,"psizz,psizh,psiz0",psizz,psizh,psiz0
      print*,"dpsi,dpsi_1,dpsi_2,dpsi_3",dpsi,dpsi_1,dpsi_2,dpsi_3
300   CONTINUE

      DO nn = 1,nmx
         c_cun = 1.0 + free_path / reff(nn) *                     &
               ( 1.257 + 0.4 * EXP( -1.1*reff(nn) / free_path ) )       ! Slip correction
         viscosity = c_stokes/c_cun                                     ! correcteddynamic viscisity(kg/m/s)

         vt = 2.0/9.0 * g0 * dden(nn) * reff(nn)**2 / viscosity       ! Settling velocity, depends on temp
         rg = 1.0 / vt                                                  !gravity resistance

         tp = vt/g0
         kp = (kbo*tmp(i,j)/(6.0*pi*viscosity*reff(nn)))               ! particle molecular diffusivity

!some variables for ra
        sct = sqrt( 1.0 + ( vt / ustar(i,j))**2 )       !KT/KP
         sc = visk / kp
        tp2 = ( tp * ustar(i,j)**2. ) / visk

        if (zh == 0) then
            b1 = 0.45
            c1 = 3.0
            ra = b1*sct*( LOG( cz/z0(i,j) )- dpsi_2)/(0.4*ustar(i,j))
           rct = 0
        else
            b1 = 1.0
            c1 = 1.0
            ra = b1*sct*( LOG( (cz-zd) / (zh-zd) ) - dpsi ) / ( 0.4*ustar(i,j))
        endif

!some variables for rs
     
        uh = ustar(i,j) / 0.4 * ( LOG( (zh + sbly -zd) / z0(i,j) ) - dpsi_1 )
        Re = uh*dc/visk
        if (Re.lt.4e3 .and.Re.ge.1)then
            cb=0.467
            nb=0.5
        elseif(Re.lt.4e4 .and.Re.ge.4e3)then
            cb=0.203
            nb=0.6
        elseif(Re.le.4e5 .and.Re.ge.4e4)then
            cb=0.025
            nb=0.8
        else
            cb=0
            nb=0
        endif
        if (dc == 0) then
            st = tp*ustar(i,j)**2./visk
            !collection efficiency
            EB = 0.
            Ein = 0.
            Eim = 0.
            wm = c1*ustar(i,j)
            rct = 0.
        else
            st = tp*ustar(i,j)/dc
            !collection efficiency
            EB = cb*Re**(nb-1.)*sc**(-2./3.)
            Ein = 10.**(-st)*4.*reff(nn)/dc*ustar(i,j)*Ain
            Eim = (st/(st+0.6))**2.
            wm = c1*ustar(i,j)**2/uh
        endif
        r = exp( -b * sqrt(st) )
        E = EB+Ein+Eim
        if (E .gt. 1.) then
            call wrf_message('E is larger than 1, set 1.')
            E = 1.
        endif
        rs = 1./(r*wm*(E/Cd*rct+(1+rct)/sc+10**(-3./tp2))+vt)

        vel_surf(i,j,nn) = 1./rs

        vd = 1./(rg+(rs-rg)/exp(ra/rg))
        dvel(i,j,nn) = vd
        vert_vel(i,j,nn) = vd-vt
        if (uh<0.) call wrf_error_fatal("uoc drydep: uh cannot be negative")

        if(vert_vel(i,j,nn)<0.) then
           call wrf_message('uoc drydep: diffusion deposition negative,reset')
           vert_vel(i,j,nn) = 0.
        endif

      ENDDO    !k_bins
  END DO  i_loop
  END DO  j_loop


  end subroutine depvel_uoc


END MODULE module_uoc_drydep
