#fsutil file createnew padding.bin 1057
#copy /b monitor-as.bin + padding.bin mon21_4kb.bin

#Bin2Array mon21_4kb.bin sys_rom.vhdl
#Bin2Array mon30.bin sys_rom.vhdl

#fsutil file createnew padding.bin 14336
#copy /b mon30p_hbasic33p.bin + padding.bin sys_rom
#Bin2Array sys_rom sys_rom.vhdl

Bin2Array keyboard.bin keyboard.vhdl