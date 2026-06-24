const options = @import("options");

//export const D3D12SDKVersion: u32 = 619;
//export const D3D12SDKPath: [*:0]const u8 = ".\\D3D12\\";

export const D3D12SDKVersion: u32 = options.NRI_AGILITY_SDK_VERSION_MAJOR;
export const D3D12SDKPath: [*:0]const u8 = options.NRI_AGILITY_SDK_DIR;
