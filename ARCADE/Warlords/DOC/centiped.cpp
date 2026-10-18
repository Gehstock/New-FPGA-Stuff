
    Main clock: XTAL = 12.096 MHz
    6502 Clock: XTAL/8 = 1.512 MHz (0.756 when accessing playfield RAM)
    Horizontal video frequency: HSYNC = XTAL/256/3 = 15.75 kHz
    Video frequency: VSYNC = HSYNC/263 ?? = 59.88593 Hz (not sure, could be /262)
    VBlank duration: 1/VSYNC * (23/263) = 1460 us

                  Warlords Memory map and Dip Switches
        ------------------------------------

     Address  R/W  D7 D6 D5 D4 D3 D2 D1 D0   Function
    --------------------------------------------------------------------------------------
    0000-03FF       D  D  D  D  D  D  D  D   RAM
    --------------------------------------------------------------------------------------
    0400-07BF       D  D  D  D  D  D  D  D   Screen RAM (8x8 TILES, 32x32 SCREEN)
    07C0-07CF       D  D  D  D  D  D  D  D   Motion Object Picture
    07D0-07DF       D  D  D  D  D  D  D  D   Motion Object Vert.
    07E0-07EF       D  D  D  D  D  D  D  D   Motion Object Horiz.
    --------------------------------------------------------------------------------------
    0800       R    D  D  D  D  D  D  D  D   Option Switch 1 (0 = On) (DSW 1)
    0801       R    D  D  D  D  D  D  D  D   Option Switch 2 (0 = On) (DSW 2)
    --------------------------------------------------------------------------------------
    0C00       R    D                        Cocktail Cabinet  (0 = Cocktail)
               R       D                     VBLANK  (1 = VBlank)
               R          D                  SELF TEST
               R             D               DIAG STEP (Unused)
    0C01       R    D  D  D                  R,C,L Coin Switches (0 = On)
               R             D               Slam (0 = On)
               R                D            Player 4 Start Switch (0 = On)
               R                   D         Player 3 Start Switch (0 = On)
               R                      D      Player 2 Start Switch (0 = On)
               R                         D   Player 1 Start Switch (0 = On)
    --------------------------------------------------------------------------------------
    1000-100F  W   D  D  D  D  D  D  D  D    Pokey
    --------------------------------------------------------------------------------------
    1800       W                             IRQ Acknowledge
    --------------------------------------------------------------------------------------
    1C00-1C02  W    D  D  D  D  D  D  D  D   Coin Counters
    --------------------------------------------------------------------------------------
    1C03-1C06  W    D  D  D  D  D  D  D  D   LEDs
    --------------------------------------------------------------------------------------
    4000       W                             Watchdog
    --------------------------------------------------------------------------------------
    5000-7FFF  R                             Program ROM
    --------------------------------------------------------------------------------------

    Game Option Settings - J2 (DSW1)
    =========================

    8   7   6   5   4   3   2   1       Option
    ------------------------------------------
                            On  On      English
                            On  Off     French
                            Off On      Spanish
                            Off Off     German
                        On              Music at end of each game
                        Off             Music at end of game for new highscore
            On  On                      1 or 2 player game costs 1 credit
            On  Off                     1 player game=1 credit, 2 player=2 credits
            Off Off                     1 or 2 player game costs 2 credits
            Off On                      Not used
    -------------------------------------------


    Game Price Settings - M2 (DSW2)
    ========================

    8   7   6   5   4   3   2   1       Option
    ------------------------------------------
                            On  On      Free play
                            On  Off     1 coin for 2 credits
                            Off On      1 coin for 1 credit
                            Off Off     2 coins for 1 credit
                    On  On              Right coin mech x 1
                    On  Off             Right coin mech x 4
                    Off On              Right coin mech x 5
                    Off Off             Right coin mech x 6
                On                      Left coin mech x 1
                Off                     Left coin mech x 2
    On  On  On                          No bonus coins
    On  On  Off                         For every 2 coins, add 1 coin
    On  Off On                          For every 4 coins, add 1 coin
    On  Off Off                         For every 4 coins, add 2 coins
    Off On  On                          For every 5 coins, add 1 coin
    ------------------------------------------

TIMER_DEVICE_CALLBACK_MEMBER(centiped_state::generate_interrupt)
{
	int scanline = param;

	/* IRQ is clocked on the rising edge of 16V, equal to the previous 32V */
	if (scanline & 16)
		m_maincpu->set_input_line(0, ((scanline - 1) & 32) ? ASSERT_LINE : CLEAR_LINE);

	/* do a partial update now to handle sprite multiplexing (Maze Invaders) */
	m_screen->update_partial(scanline);
}

void centiped_state::machine_start()
{
	save_item(NAME(m_oldpos));
	save_item(NAME(m_sign));
	save_item(NAME(m_dsw_select));

	std::fill(std::begin(m_oldpos), std::end(m_oldpos), 0);
	std::fill(std::begin(m_sign), std::end(m_sign), 0);
	m_dsw_select = 0;
}

void multiped_state::machine_start()
{
	centiped_state::machine_start();

	m_prg_bank = 0;
	m_0xxx_base = 0x1400;

	save_item(NAME(m_prg_bank));
	save_item(NAME(m_0xxx_base));
}

MACHINE_RESET_MEMBER(centiped_state,centiped)
{
	m_maincpu->set_input_line(0, CLEAR_LINE);
}

void centiped_state::irq_ack_w(uint8_t data)
{
	m_maincpu->set_input_line(0, CLEAR_LINE);
}

void centiped_state::coin_counter_left_w(int state)
{
	machine().bookkeeping().coin_counter_w(0, state);
}


void centiped_state::coin_counter_center_w(int state)
{
	machine().bookkeeping().coin_counter_w(1, state);
}


void centiped_state::coin_counter_right_w(int state)
{
	machine().bookkeeping().coin_counter_w(2, state);
}


void centiped_state::warlords_map(address_map &map)
{
	map.global_mask(0x7fff);
	map(0x0000, 0x03ff).ram();
	map(0x0400, 0x07bf).ram().w(FUNC(centiped_state::centiped_videoram_w)).share("videoram");
	map(0x07c0, 0x07ff).ram().share("spriteram");
	map(0x0800, 0x0800).portr("DSW1");
	map(0x0801, 0x0801).portr("DSW2");
	map(0x0c00, 0x0c00).portr("IN0");
	map(0x0c01, 0x0c01).portr("IN1");
	map(0x1000, 0x100f).rw("pokey", FUNC(pokey_device::read), FUNC(pokey_device::write));
	map(0x1800, 0x1800).w(FUNC(centiped_state::irq_ack_w));
	map(0x1c00, 0x1c07).w("outlatch", FUNC(ls259_device::write_d7));
	map(0x4000, 0x4000).w("watchdog", FUNC(watchdog_timer_device::reset_w));
	map(0x5000, 0x7fff).rom();
}

static INPUT_PORTS_START( warlords )
	PORT_START("IN0")
	PORT_BIT( 0x0f, IP_ACTIVE_HIGH, IPT_UNUSED )
	PORT_DIPNAME( 0x10, 0x00, "Diag Step" )             /* Not referenced */
	PORT_DIPSETTING(    0x00, DEF_STR( Off ) )
	PORT_DIPSETTING(    0x10, DEF_STR( On ) )
	PORT_SERVICE( 0x20, IP_ACTIVE_LOW )
	PORT_BIT( 0x40, IP_ACTIVE_HIGH, IPT_CUSTOM ) PORT_READ_LINE_DEVICE_MEMBER("screen", FUNC(screen_device::vblank))
	PORT_DIPNAME( 0x80, 0x00, DEF_STR( Cabinet ) )
	PORT_DIPSETTING(    0x80, "Upright (overlay)" )
	PORT_DIPSETTING(    0x00, "Cocktail (no overlay)" )

	PORT_START("IN1")
	PORT_BIT( 0x01, IP_ACTIVE_LOW, IPT_BUTTON1 ) PORT_PLAYER(1)
	PORT_BIT( 0x02, IP_ACTIVE_LOW, IPT_BUTTON1 ) PORT_PLAYER(2)
	PORT_BIT( 0x04, IP_ACTIVE_LOW, IPT_BUTTON1 ) PORT_PLAYER(3)
	PORT_BIT( 0x08, IP_ACTIVE_LOW, IPT_BUTTON1 ) PORT_PLAYER(4)
	PORT_BIT( 0x10, IP_ACTIVE_LOW, IPT_TILT )
	PORT_BIT( 0x20, IP_ACTIVE_LOW, IPT_COIN1 )
	PORT_BIT( 0x40, IP_ACTIVE_LOW, IPT_COIN2 )
	PORT_BIT( 0x80, IP_ACTIVE_LOW, IPT_SERVICE1 )

	PORT_START("DSW1")
	PORT_DIPNAME( 0x03, 0x00, DEF_STR( Language ) )     PORT_DIPLOCATION("J2:1,2")
	PORT_DIPSETTING(    0x00, DEF_STR( English ) )
	PORT_DIPSETTING(    0x01, DEF_STR( French ) )
	PORT_DIPSETTING(    0x02, DEF_STR( Spanish ) )
	PORT_DIPSETTING(    0x03, DEF_STR( German ) )
	PORT_DIPNAME( 0x04, 0x00, "Music" )                 PORT_DIPLOCATION("J2:3")
	PORT_DIPSETTING(    0x00, "End of game" )
	PORT_DIPSETTING(    0x04, "High score only" )
	PORT_DIPUNKNOWN_DIPLOC( 0x08, 0x00, "J2:4" )
	PORT_DIPNAME( 0x30, 0x00, "Credits" )               PORT_DIPLOCATION("J2:5,6")
	PORT_DIPSETTING(    0x00, "1p/2p = 1 credit" )
	PORT_DIPSETTING(    0x10, "1p = 1, 2p = 2" )
	PORT_DIPSETTING(    0x20, "1p/2p = 2 credits" )
	PORT_DIPUNKNOWN_DIPLOC( 0x40, 0x00, "J2:7" )
	PORT_DIPUNKNOWN_DIPLOC( 0x80, 0x00, "J2:8" )


	PORT_START("DSW2")
	PORT_DIPNAME( 0x03, 0x02, DEF_STR( Coinage ) )      PORT_DIPLOCATION("M2:1,2")
	PORT_DIPSETTING(    0x03, DEF_STR( 2C_1C ) )
	PORT_DIPSETTING(    0x02, DEF_STR( 1C_1C ) )
	PORT_DIPSETTING(    0x01, DEF_STR( 1C_2C ) )
	PORT_DIPSETTING(    0x00, DEF_STR( Free_Play ) )
	PORT_DIPNAME( 0x0c, 0x00, "Right Coin" )            PORT_DIPLOCATION("M2:3,4")
	PORT_DIPSETTING(    0x00, "*1" )
	PORT_DIPSETTING(    0x04, "*4" )
	PORT_DIPSETTING(    0x08, "*5" )
	PORT_DIPSETTING(    0x0c, "*6" )
	PORT_DIPNAME( 0x10, 0x00, "Left Coin" )             PORT_DIPLOCATION("M2:5")
	PORT_DIPSETTING(    0x00, "*1" )
	PORT_DIPSETTING(    0x10, "*2" )
	PORT_DIPNAME( 0xe0, 0x00, "Bonus Coins" )           PORT_DIPLOCATION("M2:6,7,8")
	PORT_DIPSETTING(    0x00, DEF_STR( None ) )
	PORT_DIPSETTING(    0x20, "3 credits/2 coins" )
	PORT_DIPSETTING(    0x40, "5 credits/4 coins" )
	PORT_DIPSETTING(    0x60, "6 credits/4 coins" )
	PORT_DIPSETTING(    0x80, "6 credits/5 coins" )

	/* IN4-7 fake to control player paddles */
	PORT_START("PADDLE0")
	PORT_BIT( 0xff, 0x80, IPT_PADDLE ) PORT_MINMAX(0x1d,0xcb) PORT_SENSITIVITY(50) PORT_KEYDELTA(10) PORT_CENTERDELTA(0) PORT_PLAYER(1)

	PORT_START("PADDLE1")
	PORT_BIT( 0xff, 0x80, IPT_PADDLE ) PORT_MINMAX(0x1d,0xcb) PORT_SENSITIVITY(50) PORT_KEYDELTA(10) PORT_CENTERDELTA(0) PORT_PLAYER(2)

	PORT_START("PADDLE2")
	PORT_BIT( 0xff, 0x80, IPT_PADDLE ) PORT_MINMAX(0x1d,0xcb) PORT_SENSITIVITY(50) PORT_KEYDELTA(10) PORT_CENTERDELTA(0) PORT_PLAYER(3)

	PORT_START("PADDLE3")
	PORT_BIT( 0xff, 0x80, IPT_PADDLE ) PORT_MINMAX(0x1d,0xcb) PORT_SENSITIVITY(50) PORT_KEYDELTA(10) PORT_CENTERDELTA(0) PORT_PLAYER(4)
INPUT_PORTS_END


static const gfx_layout warlords_charlayout =
{
	8,8,
	RGN_FRAC(1,4),
	2,
	{ RGN_FRAC(1,2), 0 },
	{ 0, 1, 2, 3, 4, 5, 6, 7 },
	{ 0*8, 1*8, 2*8, 3*8, 4*8, 5*8, 6*8, 7*8 },
	8*8
};

static GFXDECODE_START( gfx_warlords )
	GFXDECODE_ENTRY( "gfx1", 0x000, warlords_charlayout, 0,   8 )
	GFXDECODE_ENTRY( "gfx1", 0x200, warlords_charlayout, 8*4, 8*4 )
GFXDECODE_END


void centiped_state::centiped_base(machine_config &config)
{
	/* basic machine hardware */
	M6502(config, m_maincpu, 12096000/8);  /* 1.512 MHz (slows down to 0.75MHz while accessing playfield RAM) */

	MCFG_MACHINE_RESET_OVERRIDE(centiped_state,centiped)

	ER2055(config, m_earom);

	LS259(config, m_outlatch);
	m_outlatch->q_out_cb<0>().set(FUNC(centiped_state::coin_counter_left_w));
	m_outlatch->q_out_cb<1>().set(FUNC(centiped_state::coin_counter_center_w));
	m_outlatch->q_out_cb<2>().set(FUNC(centiped_state::coin_counter_right_w));
	m_outlatch->q_out_cb<3>().set_output("led0").invert(); // LED 1
	m_outlatch->q_out_cb<4>().set_output("led1").invert(); // LED 2

	WATCHDOG_TIMER(config, "watchdog").set_vblank_count("screen", 8);

	/* timer */
	TIMER(config, "32v").configure_scanline(FUNC(centiped_state::generate_interrupt), "screen", 0, 16);

	/* video hardware */
	SCREEN(config, m_screen, SCREEN_TYPE_RASTER);
	m_screen->set_refresh_hz(60);
	m_screen->set_size(32*8, 32*8);
	m_screen->set_visarea(0*8, 32*8-1, 0*8, 30*8-1);
	m_screen->set_screen_update(FUNC(centiped_state::screen_update_centiped));
	m_screen->set_palette(m_palette);

	GFXDECODE(config, m_gfxdecode, m_palette, gfx_centiped);
	PALETTE(config, m_palette).set_entries(4+4*4*4*4);

	MCFG_VIDEO_START_OVERRIDE(centiped_state,centiped)
}


void centiped_state::warlords(machine_config &config)
{
	centiped_base(config);

	/* basic machine hardware */
	m_maincpu->set_addrmap(AS_PROGRAM, &centiped_state::warlords_map);

	config.device_remove("earom");

	// these extra LEDs also appear on Centipede schematics
	// P9
	m_outlatch->q_out_cb<5>().set_output("led2").invert(); // LED 3
	m_outlatch->q_out_cb<6>().set_output("led3").invert(); // LED 4

	/* video hardware */
	m_gfxdecode->set_info(gfx_warlords);
	m_palette->set_entries(8*4+8*4);
	m_palette->set_init(FUNC(centiped_state::warlords_palette));

	MCFG_VIDEO_START_OVERRIDE(centiped_state,warlords)

	m_screen->set_screen_update(FUNC(centiped_state::screen_update_warlords));

	/* sound hardware */
	SPEAKER(config, "mono").front_center();

	pokey_device &pokey(POKEY(config, "pokey", 12096000/8));
	pokey.pot_r<0>().set_ioport("PADDLE0");
	pokey.pot_r<1>().set_ioport("PADDLE1");
	pokey.pot_r<2>().set_ioport("PADDLE2");
	pokey.pot_r<3>().set_ioport("PADDLE3");
	pokey.add_route(ALL_OUTPUTS, "mono", 1.0);
}

ROM_START( warlords )
	ROM_REGION( 0x10000, "maincpu", 0 )
	ROM_LOAD( "037154-01.m1", 0x5000, 0x0800, CRC(18006c87) SHA1(6b4aab1b1710819d29f4bbc29269eb9c915626c0) )
	ROM_LOAD( "037153-01.k1", 0x5800, 0x0800, CRC(67758f4c) SHA1(b65ca677b54de7a8202838207d9a7bb0aed3e0f2) )
	ROM_LOAD( "037158-01.j1", 0x6000, 0x0800, CRC(1f043a86) SHA1(b1e271c0979d62202ae86c4b6860fb67bbef6400) )
	ROM_LOAD( "037157-01.h1", 0x6800, 0x0800, CRC(1a639100) SHA1(41ec333aee7192f8aeef49e5257f201f4db01cff) )
	ROM_LOAD( "037156-01.e1", 0x7000, 0x0800, CRC(534f34b4) SHA1(1680982ded17350c2ae10bb47f7eb8908bb10db2) )
	ROM_LOAD( "037155-01.d1", 0x7800, 0x0800, CRC(23b94210) SHA1(d74c1ca90caf15942805043b4ebe4ee077799da0) )

	ROM_REGION( 0x0800, "gfx1", 0 )
	ROM_LOAD( "037159-01.e6", 0x0000, 0x0800, CRC(ff979a08) SHA1(422053473e41e3e1f71eb28e40eedc78f22326b3) )

	ROM_REGION( 0x0200, "proms", 0 ) // dumped from 3 different PCBs
	/* Only the first 0x80 bytes are used by the hardware. A7 is grounded. */
	/* Bytes 0x00-0x3f are used for the color cocktail version. */
	/* Bytes 0x40-0x7f are for the upright version of the cabinet with a */
	/* mirror and painted background. */
	ROM_LOAD( "037235-01.n7", 0x0000, 0x0100, CRC(a2c5c277) SHA1(f04de9fb6ee9619b4a4aae10c92b16b3123046cf) )
	ROM_LOAD( "037161-01.m6", 0x0100, 0x0100, CRC(6fa3093a) SHA1(2b7aeca74c1ae4156bf1878453a047330f96f0a8) ) // Sync PROM
ROM_END

GAME( 1980, warlords,  0,        warlords,  warlords,  centiped_state, empty_init,    ROT0,   "Atari", "Warlords", MACHINE_SUPPORTS_SAVE )
