program ac1_prep;

uses
  SysUtils, Classes;

var
  SearchRec: TSearchRec;
  FileName, BaseName, HexStr, OutFileName: String;
  UnderscorePos: Integer;
  AddrWord: Word;
  HighByte, LowByte: Byte;
  InFile, OutFile: TFileStream;
  i: Integer;

begin
  Writeln('AC1 FPGA-ROM Preparer v1.0 by Gehstock');
  Writeln('Searching for .bin files in the current directory...');
  Writeln('--------------------------------------------------');

  if FindFirst('*.bin', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      FileName := SearchRec.Name;
      BaseName := ChangeFileExt(FileName, '');
      UnderscorePos := 0;
      for i := 1 to Length(BaseName) - 4 do
      begin
        if (BaseName[i] = '_') and
           (BaseName[i+1] in ['0'..'9', 'A'..'F', 'a'..'f']) and
           (BaseName[i+2] in ['0'..'9', 'A'..'F', 'a'..'f']) and
           (BaseName[i+3] in ['0'..'9', 'A'..'F', 'a'..'f']) and
           (BaseName[i+4] in ['0'..'9', 'A'..'F', 'a'..'f']) then
        begin
          UnderscorePos := i;
          Break;
        end;
      end;

      if UnderscorePos > 0 then
      begin
        HexStr := Copy(BaseName, UnderscorePos + 1, 4);

        try
          AddrWord := StrToInt('$' + HexStr);

          HighByte := Hi(AddrWord);
          LowByte  := Lo(AddrWord);

          Writeln(Format('Processing: %-35s -> Start Address: $%s', [FileName, HexStr]));

          OutFileName := BaseName + '.mst';

          InFile  := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
          OutFile := TFileStream.Create(OutFileName, fmCreate);
          try
            OutFile.Write(HighByte, 1);
            OutFile.Write(LowByte, 1);
            OutFile.CopyFrom(InFile, InFile.Size);
          finally
            OutFile.Free;
            InFile.Free;
          end;

        except
          on E: EConvertError do
            Writeln('Error: Conversion failed for file: ', FileName);
        end;
      end
      else
        Writeln('Skipped (No valid hex address pattern found): ', FileName);

    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;

  Writeln('--------------------------------------------------');
  Writeln('Done! All prepared files now have the ".mst" extension.');
  Writeln('Press Enter to exit...');
  Readln;
end.

