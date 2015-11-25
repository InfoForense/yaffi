// Original Delphi code supplied by David Heffernan as answer to Stack Overflow URL
// http://stackoverflow.com/a/17132506
// Adjusted for use with YAFFI and Freepascal and then converted to GPTMBR unit
// by T Smith July 2015

unit GPTMBR;

{$mode objfpc}{$H+}

interface

uses
  {$ifdef Windows}
  Windows, SysUtils, Dialogs;
  {$endif}
  {$ifdef UNIX}
  SysUtils;
  {$endif}
type
  TDriveLayoutInformationMbr = record
    Signature: DWORD;
  end;

  TDriveLayoutInformationGpt = record
    DiskId: TGuid;
    StartingUsableOffset: Int64;
    UsableLength: Int64;
    MaxPartitionCount: DWORD;
  end;

  TPartitionInformationMbr = record
    PartitionType: Byte;
    BootIndicator: Boolean;
    RecognizedPartition: Boolean;
    HiddenSectors: DWORD;
  end;

  TPartitionInformationGpt = record
    PartitionType: TGuid;
    PartitionId: TGuid;
    Attributes: Int64;
    Name: array [0..35] of WideChar;
  end;

  TPartitionInformationEx = record
    PartitionStyle: Integer;
    StartingOffset: Int64;
    PartitionLength: Int64;
    PartitionNumber: DWORD;
    RewritePartition: Boolean;
    case Integer of
      0: (Mbr: TPartitionInformationMbr);
      1: (Gpt: TPartitionInformationGpt);
  end;

  TDriveLayoutInformationEx = record
    PartitionStyle: DWORD;
    PartitionCount: DWORD;
    DriveLayoutInformation: record
      case Integer of
      0: (Mbr: TDriveLayoutInformationMbr);
      1: (Gpt: TDriveLayoutInformationGpt);
    end;
    PartitionEntry: array [0..15] of TPartitionInformationGpt;
    //hard-coded maximum of 16 partitions
  end;


function MBR_or_GPT(SelectedDisk : widestring) : string;

implementation

// Returns the partitioning style of a physical disk by utilising sector 0
// offset 440 for MBR or offset 38 of sector 1 for GPT. Returns resulting
// text string and Windows signature
function MBR_or_GPT(SelectedDisk : widestring) : string; 

const
  PARTITION_STYLE_MBR = 0;
  PARTITION_STYLE_GPT = 1;
  PARTITION_STYLE_RAW = 2;

  IOCTL_DISK_GET_DRIVE_LAYOUT_EX = $00070050;
  IOCTL_DISK_GET_PARTITION_INFO_EX = $0070048;
var
  i: Integer;
  Drive: widestring;
  hDevice: THandle;
  DriveLayoutInfo: TDriveLayoutInformationEx;
  GPTPartitionLayoutInfo : TPartitionInformationEx;
  BytesReturned: DWORD;
  DiskGUID, GPTGUIDType : string;
begin
    result := '';
    Drive := SelectedDisk;

    // This particular handle assignment does not require admin rights as it allows
    // simply to query the device attributes without accessing actual disk data as such
    {$ifdef Windows}
    hDevice := CreateFileW(PWideChar(Drive),
                          0,
                          FILE_SHARE_READ or FILE_SHARE_WRITE,
                          nil,
                          OPEN_EXISTING,
                          0,
                          0);

    if hDevice <> INVALID_HANDLE_VALUE then
    begin
      if DeviceIoControl(hDevice, IOCTL_DISK_GET_DRIVE_LAYOUT_EX, nil, 0,
        @DriveLayoutInfo, SizeOf(DriveLayoutInfo), @BytesReturned, nil) then
      begin
        // The disk has MBR partitioning
        if DriveLayoutInfo.PartitionStyle = 0 then
          begin
            result := 'MBR (sig: ' + IntToHex(SwapEndian(DriveLayoutInfo.DriveLayoutInformation.Mbr.Signature), 8) + ')';
          end  // End of MBR

        // The disk has GPT partitioning
        else if DriveLayoutInfo.PartitionStyle = 1 then
        begin
          DiskGUID := GUIDToString(DriveLayoutInfo.DriveLayoutInformation.Gpt.DiskId);
          begin
            // Run DeviceIOControl again but store the GPT data instead.
            // This can be obtained via either IOCTL_DISK_GET_DRIVE_LAYOUT_EX
            // or IOCTL_DISK_GET_PARTITION_INFO_EX as long as GPTPartitionLayoutInfo
            // is defined as type TPartitionInformationEx.

            if DeviceIoControl(hDevice, IOCTL_DISK_GET_PARTITION_INFO_EX, nil, 0,
              @GPTPartitionLayoutInfo, SizeOf(GPTPartitionLayoutInfo), @BytesReturned, nil) then
              begin
                GPTGUIDType := GUIDToString(GPTPartitionLayoutInfo.Gpt.PartitionType);
                ShowMessage(' GPT Type GUID is ' + GPTGUIDType + ' name is: ' + GPTPartitionLayoutInfo.Gpt.Name);
                result := 'DiskGUID: ' + DiskGUID + ' GUID Type: ' + GPTGUIDType;
              end
            else
              begin
                RaiseLastOSError; // second DeviceIOControl failed
                CloseHandle(hDevice);
              end;
          end;
        end // End of GPT

        // The disk has RAW partitioning
        else if DriveLayoutInfo.PartitionStyle = 2 then
          begin
            result := 'RAW (no signature)';
          end; // End of raw partitioning
      end
        else
        begin
          RaiseLastOSError; // first DeviceIOControl failed
          CloseHandle(hDevice);
        end;
    end;
    {$endif}

    {$ifdef UNIX}
    // TODO work out Linux way of doing this instead of Windows handles
    {
    hDevice := CreateFileW(PWideChar(Drive),
                              0,
                              FILE_SHARE_READ or FILE_SHARE_WRITE,
                              nil,
                              OPEN_EXISTING,
                              0,
                              0);

        if hDevice <> INVALID_HANDLE_VALUE then
        begin
          if DeviceIoControl(hDevice, IOCTL_DISK_GET_DRIVE_LAYOUT_EX, nil, 0,
            @DriveLayoutInfo, SizeOf(DriveLayoutInfo), BytesReturned, nil) then
          begin
            if DriveLayoutInfo.PartitionStyle = 0 then result := 'MBR (sig: ' + IntToHex(SwapEndian(DriveLayoutInfo.DriveLayoutInformation.Mbr.Signature), 8) + ')';
            if DriveLayoutInfo.PartitionStyle = 1 then result := 'GPT (sig: ' + GUIDToString(DriveLayoutInfo.DriveLayoutInformation.Gpt.DiskId) + ')';
            if DriveLayoutInfo.PartitionStyle = 2 then result := 'RAW (no signature)';
          end;
        end;
        CloseHandle(hDevice);
      }
    {$endif}
  end;

end.

