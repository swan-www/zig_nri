const std = @import("std");
const builtin = @import("builtin");

const Dependency = std.Build.Dependency;

const OptionFlag = struct {
    flag_str: []const u8,
    val: bool,

    pub fn option(b: *std.Build, flag: []const u8, description_raw: []const u8, default_val: bool) @This() {
        const opt = b.option(bool, flag, description_raw);
        return .{
            .flag_str = flag,
            .val = opt orelse default_val,
        };
    }
};

const NRIOptions = struct {
    EnableNVTXSupport: OptionFlag,
    EnableDebugNamesAndAnnotations: OptionFlag,
    EnableNoneSupport: OptionFlag,
    EnableVKSupport: OptionFlag,
    EnableValidationSupport: OptionFlag,
    EnableNISSdk: OptionFlag,
    EnableImguiExtension: OptionFlag,
    StreamerThreadSafe: OptionFlag,

    //EnableD3D11Support: OptionFlag,
    EnableD3D12Support: OptionFlag,
    EnableAMDAGS: OptionFlag,
    EnableNVAPI: OptionFlag,
    EnableAgilitySdkSupport: OptionFlag,
    EnableXLIBSupport: OptionFlag,
    EnableWaylandSupport: OptionFlag,
    EnableNGXSDK: OptionFlag,
    EnableFFXSDK: OptionFlag,
    EnableXESSSDK: OptionFlag,

    EnableShaderMake: OptionFlag,
    EnableNRISamples: OptionFlag,

    pub fn init(b: *std.Build, target: std.Build.ResolvedTarget) @This() {
        var opt: @This() = undefined;
        opt.EnableNVTXSupport = OptionFlag.option(b, "NRI_ENABLE_NVTX_SUPPORT", "Annotations for NVIDIA Nsight Systems.", true);
        opt.EnableDebugNamesAndAnnotations = OptionFlag.option(b, "NRI_ENABLE_DEBUG_NAMES_AND_ANNOTATIONS", "Enable debug names, host and device annotations.", true);
        opt.EnableNoneSupport = OptionFlag.option(b, "NRI_ENABLE_NONE_SUPPORT", "Enable NONE backend.", true);
        opt.EnableVKSupport = OptionFlag.option(b, "NRI_ENABLE_VK_SUPPORT", "Enable Vulkan backend.", true);
        opt.EnableValidationSupport = OptionFlag.option(b, "NRI_ENABLE_VALIDATION_SUPPORT", "Enable Validation backend (otherwise 'enableNRIValidation' is ignored)", true);
        opt.EnableNISSdk = OptionFlag.option(b, "NRI_ENABLE_NIS_SDK", "Enable NVIDIA Image Sharpening SDK", false);
        opt.StreamerThreadSafe = OptionFlag.option(b, "NRI_STREAMER_THREAD_SAFE", "NRIStreamer thread safety (OFF is faster)", true);
        //opt.EnableD3D11Support = OptionFlag.option(b, "NRI_ENABLE_D3D11_SUPPORT", "Enable D3D11 backend.", (target.result.os.tag == .windows));
        opt.EnableD3D12Support = OptionFlag.option(b, "NRI_ENABLE_D3D12_SUPPORT", "Enable D3D12 backend.", (target.result.os.tag == .windows));
        const d3d_non_arm_dep = ((opt.EnableD3D12Support.val) and (target.result.cpu.arch != .aarch64));
        opt.EnableAMDAGS = OptionFlag.option(b, "NRI_ENABLE_AMDAGS", "Enable AMD AGS library for D3D", d3d_non_arm_dep);
        opt.EnableNVAPI = OptionFlag.option(b, "NRI_ENABLE_NVAPI", "Enable NVAPI library for D3D", d3d_non_arm_dep);
        opt.EnableAgilitySdkSupport = OptionFlag.option(b, "NRI_ENABLE_AGILITY_SDK_SUPPORT", "Enable Agility SDK support to unlock access to latest D3D12 features", opt.EnableD3D12Support.val);
        opt.EnableXLIBSupport = OptionFlag.option(b, "NRI_ENABLE_XLIB_SUPPORT", "Enable X11 support", false); //TODO
        opt.EnableWaylandSupport = OptionFlag.option(b, "NRI_ENABLE_WAYLAND_SUPPORT", "Enable Wayland support", false); //TODO
        const ngx_dep = ((opt.EnableD3D12Support.val or opt.EnableVKSupport.val) and (target.result.cpu.arch != .aarch64));
        opt.EnableNGXSDK = OptionFlag.option(b, "NRI_ENABLE_NGX_SDK", "Enable NVIDIA NGX (DLSS) SDK", ngx_dep);
        const ffx_dep = ((opt.EnableVKSupport.val or opt.EnableD3D12Support.val) and (target.result.os.tag == .windows) and (target.result.cpu.arch != .aarch64));
        opt.EnableFFXSDK = OptionFlag.option(b, "NRI_ENABLE_FFX_SDK", "Enable AMD FidelityFX SDK", ffx_dep);
        const xess_dep = ((opt.EnableD3D12Support.val) and (target.result.os.tag == .windows) and (target.result.cpu.arch != .aarch64));
        opt.EnableXESSSDK = OptionFlag.option(b, "NRI_ENABLE_XESS_SDK", "Enable INTEL XeSS SDK", xess_dep);

        opt.EnableNRISamples = OptionFlag.option(b, "NRI_ENABLE_SAMPLES", "Enable NRI Samples", false);
        opt.EnableImguiExtension = OptionFlag.option(b, "NRI_ENABLE_IMGUI_EXTENSION", "Enable imgui rendering support", opt.EnableNRISamples.val);
        opt.EnableShaderMake = OptionFlag.option(b, "NRI_ENABLE_SHADERMAKE", "Enable ShaderMake", opt.EnableNRISamples.val or opt.EnableNISSdk.val or opt.EnableImguiExtension.val);
        return opt;
    }

    pub fn apply_defines_to_translate(self: @This(), translate: *std.Build.Step.TranslateC) void {
        const fields = std.meta.fields(@This());
        inline for (fields) |field| {
            const field_define = @field(self, field.name).flag_str;
            if (@field(self, field.name).val) {
                translate.defineCMacroRaw(field_define);
            }
        }
    }

    pub fn get_defines(self: @This(), allocator: std.mem.Allocator) [][]const u8 {
        var num_defines: usize = 0;
        const fields = std.meta.fields(@This());
        inline for (fields) |field| {
            if (@field(self, field.name).val) {
                num_defines += 1;
            }
        }

        const defines_slice = allocator.alloc([]const u8, num_defines) catch @panic("build allocator oom");
        var define_index: usize = 0;
        inline for (fields) |field| {
            const field_define = @field(self, field.name).flag_str;
            if (@field(self, field.name).val) {
                defines_slice[define_index] = std.fmt.allocPrint(allocator, "-D{s}", .{field_define}) catch @panic("build allocator oom");
                define_index += 1;
            }
        }
        return defines_slice;
    }
};

pub fn installFile(b: *std.Build, dep: ?*std.Build.Step, src_path: std.Build.LazyPath, dest_path: []const u8) void {
    const installedFile = b.addInstallFile(src_path, dest_path);
    if (dep) |_| installedFile.step.dependOn(dep.?);
    b.getInstallStep().dependOn(&installedFile.step);
}

pub fn installBinFile(b: *std.Build, dep: ?*std.Build.Step, src_path: std.Build.LazyPath, dest_path: []const u8) void {
    const installedFile = b.addInstallBinFile(src_path, dest_path);
    if (dep) |_| installedFile.step.dependOn(dep.?);
    b.getInstallStep().dependOn(&installedFile.step);
}

pub fn installArtifact(b: *std.Build, dep: *std.Build.Step.Compile) void {
    const installedFile = b.addInstallArtifact(dep, .{});
    installedFile.step.dependOn(&dep.step);
    b.getInstallStep().dependOn(&installedFile.step);
}

const NRI_AGILITY_SDK_VERSION_MAJOR = "619";
const NGX_VERSION = "310.6.0";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const nri_options = NRIOptions.init(b, target);

    //Set the output directory to use a per-target folder
    const joined_target_str = try std.mem.concat(b.allocator, u8, &.{ @tagName(target.result.cpu.arch), "_", @tagName(target.result.os.tag), "_", @tagName(target.result.abi) });
    b.lib_dir = try std.fs.path.join(b.allocator, &.{ b.install_path, joined_target_str, "lib" });
    b.h_dir = try std.fs.path.join(b.allocator, &.{ b.install_path, joined_target_str, "include" });
    b.exe_dir = try std.fs.path.join(b.allocator, &.{ b.install_path, joined_target_str, "bin" });
    b.dest_dir = try std.fs.path.join(b.allocator, &.{ b.install_path, joined_target_str });

    const nri = b.lazyDependency("nri", .{});
    const nri_samples = if (nri_options.EnableNRISamples.val) b.lazyDependency("nri_samples", .{}) else null;
    const dx12_headers = if (nri_options.EnableD3D12Support.val) b.lazyDependency("dx12_headers", .{}) else null;
    const agility_sdk = if (nri_options.EnableAgilitySdkSupport.val) b.lazyDependency("agility_sdk", .{}) else null;
    const nvtx = if (nri_options.EnableNVTXSupport.val) b.lazyDependency("nvtx", .{}) else null;
    const vulkan_headers = if (nri_options.EnableVKSupport.val) b.lazyDependency("vulkan_headers", .{}) else null;
    const vulkan_allocator = if (nri_options.EnableVKSupport.val) b.lazyDependency("vulkan_allocator", .{}) else null;
    const ngx_sdk = if (nri_options.EnableNGXSDK.val) b.lazyDependency("ngx_sdk", .{}) else null;
    const ffx_sdk = if (nri_options.EnableFFXSDK.val) b.lazyDependency("ffx_sdk", .{}) else null;
    const xess_sdk = if (nri_options.EnableXESSSDK.val) b.lazyDependency("xess_sdk", .{}) else null;
    const d3d12_allocator = if (nri_options.EnableD3D12Support.val) b.lazyDependency("d3d12_allocator", .{}) else null;
    const amd_ags = if (nri_options.EnableAMDAGS.val) b.lazyDependency("amd_ags", .{}) else null;
    const nvapi = if (nri_options.EnableNVAPI.val) b.lazyDependency("nvapi", .{}) else null;
    const shadermake = if (nri_options.EnableShaderMake.val) b.lazyDependency("shadermake", .{}) else null;

    _ = &agility_sdk;
    _ = &nvtx;
    _ = &vulkan_headers;
    _ = &vulkan_allocator;
    _ = &ngx_sdk;
    _ = &ffx_sdk;
    _ = &xess_sdk;
    _ = &d3d12_allocator;
    _ = &amd_ags;
    _ = &nvapi;
    _ = &shadermake;

    const translate_nri = b.addTranslateC(.{
        .root_source_file = b.path("nri.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_nri.addIncludePath(b.path(""));
    nri_options.apply_defines_to_translate(translate_nri);
    const mod_translate_nri = translate_nri.addModule("nri_translate");
    _ = &mod_translate_nri;

    const mod_nri = b.addModule("nri", .{
        .target = target,
        .optimize = optimize,
        .sanitize_thread = false,
        .sanitize_c = .off,
    });
    const lib_nri = b.addLibrary(.{
        .name = "lib_nri",
        .root_module = mod_nri,
    });
    lib_nri.linkLibC();
    b.installArtifact(lib_nri);

    const installed_nri_zig = try std.fs.path.join(b.allocator, &.{ joined_target_str, "nri.zig" });
    installFile(b, &translate_nri.step, translate_nri.getOutput(), installed_nri_zig);

    const nri_option_defines = nri_options.get_defines(b.allocator);
    const nri_compile_defines = &.{
        "-DWIN32_LEAN_AND_MEAN",
        "-DNOMINMAX",
        "-D_CRT_SECURE_NO_WARNINGS",
        "-std=c++17",
        "-Wno-missing-field-initializers",
        "-Wno-nullability-completeness",
    };
    var vk_flags: []const []const u8 = &.{};
    const vk_flags_backing = try b.allocator.alloc([]const u8, 6);
    if (nri_options.EnableVKSupport.val) {
        var num_vk_flags: usize = 0;

        if (target.result.os.tag == .windows) {
            vk_flags_backing[num_vk_flags] = "-DVK_USE_PLATFORM_WIN32_KHR";
            num_vk_flags += 1;
        }

        if (target.result.os.tag == .macos) {
            vk_flags_backing[num_vk_flags] = "-DVK_USE_PLATFORM_METAL_EXT";
            num_vk_flags += 1;
            vk_flags_backing[num_vk_flags] = "-DVK_ENABLE_BETA_EXTENSIONS";
            num_vk_flags += 1;
        }

        if (nri_options.EnableXLIBSupport.val) {
            vk_flags_backing[num_vk_flags] = "-DVK_USE_PLATFORM_XLIB_KHR";
            num_vk_flags += 1;
        }

        if (nri_options.EnableWaylandSupport.val) {
            vk_flags_backing[num_vk_flags] = "-DVK_USE_PLATFORM_WAYLAND_KHR";
            num_vk_flags += 1;
        }

        vk_flags = vk_flags_backing[0..num_vk_flags];
    }
    const nri_joined_defines = try std.mem.concat(b.allocator, []const u8, &.{ nri_option_defines, nri_compile_defines, vk_flags });
    translate_nri.defineCMacroRaw("WIN32_LEAN_AND_MEAN");
    translate_nri.defineCMacroRaw("NOMINMAX");
    translate_nri.defineCMacroRaw("_CRT_SECURE_NO_WARNINGS");
    for (vk_flags) |def| {
        translate_nri.defineCMacroRaw(def[2..]);
    }

    //NRI
    var lib_nri_shared: *std.Build.Step.Compile = undefined;
    if (nri) |_| {
        lib_nri_shared = b.addLibrary(.{
            .name = "lib_nri_shared",
            .root_module = b.addModule("nri_shared", .{
                .target = target,
                .optimize = optimize,
                .sanitize_thread = false,
                .sanitize_c = .off,
            }),
        });

        lib_nri_shared.root_module.addCSourceFile(.{
            .file = nri.?.path("Source/Creation/Creation.cpp"),
            .flags = nri_joined_defines,
            .language = .cpp,
        });

        lib_nri_shared.root_module.addCSourceFiles(.{
            .root = nri.?.path(""),
            .files = &nri_shared_src,
            .flags = nri_joined_defines,
            .language = .cpp,
        });
        lib_nri_shared.linkLibC();

        mod_nri.linkLibrary(lib_nri_shared);
        mod_nri.addWin32ResourceFile(.{
            .file = nri.?.path("Resources/NRI.rc"),
        });
        //const installed_resource_file_path = try std.fs.path.join(b.allocator, &.{ joined_target_str, "Resources/NRI.rc" });
        installBinFile(b, null, nri.?.path("Resources/NRI.rc"), "NRI.rc");

        if (target.result.os.tag == .windows) {
            //mod_nri.linkSystemLibrary("kernel32", .{ .preferred_link_mode = .static });
            //mod_nri.linkSystemLibrary("user32", .{ .preferred_link_mode = .static });
            mod_nri.linkSystemLibrary("gdi32", .{ .preferred_link_mode = .static });
            //mod_nri.linkSystemLibrary("winspool", .{ .preferred_link_mode = .static });
            //mod_nri.linkSystemLibrary("shell32", .{ .preferred_link_mode = .static });
            //mod_nri.linkSystemLibrary("ole32", .{ .preferred_link_mode = .static });
            //mod_nri.linkSystemLibrary("oleaut32", .{ .preferred_link_mode = .static });
            //mod_nri.linkSystemLibrary("uuid", .{ .preferred_link_mode = .static });
            //mod_nri.linkSystemLibrary("comdlg32", .{ .preferred_link_mode = .static });
            mod_nri.linkSystemLibrary("advapi32", .{ .preferred_link_mode = .static });
        }

        lib_nri_shared.root_module.addIncludePath(nri.?.path("Include"));
        lib_nri_shared.root_module.addIncludePath(nri.?.path("Source/Shared"));
        translate_nri.addIncludePath(nri.?.path(""));

        //FFX
        if (ffx_sdk) |_| {
            lib_nri_shared.root_module.addIncludePath(ffx_sdk.?.path("ffx-api/include/ffx_api"));
        }

        //XESS
        if (xess_sdk) |_| {
            lib_nri_shared.root_module.addIncludePath(xess_sdk.?.path("inc/xess"));
        }

        if (nvtx) |_| {
            lib_nri_shared.root_module.addIncludePath(nvtx.?.path("c/include"));
        }

        if (ngx_sdk) |_| {
            lib_nri_shared.root_module.addIncludePath(ngx_sdk.?.path("include"));
        }

        //d3d12
        if (nri_options.EnableD3D12Support.val) {
            mod_nri.linkSystemLibrary("d3d12", .{ .needed = true, .preferred_link_mode = .dynamic });
            mod_nri.linkSystemLibrary("dxgi", .{ .needed = true, .preferred_link_mode = .dynamic });
            mod_nri.linkSystemLibrary("dxguid", .{ .needed = true, .preferred_link_mode = .static });

            const lib_nri_d3d12 = b.addLibrary(.{
                .name = "lib_nri_d3d12",
                .root_module = b.addModule("nri_d3d12", .{
                    .target = target,
                    .optimize = optimize,
                    .sanitize_thread = false,
                    .sanitize_c = .off,
                }),
                .linkage = .static,
            });

            lib_nri_d3d12.root_module.addCSourceFiles(.{
                .root = nri.?.path(""),
                .files = &nri_d3d12_src,
                .flags = nri_joined_defines,
                .language = .cpp,
            });
            lib_nri_d3d12.root_module.addIncludePath(nri.?.path("Include"));
            lib_nri_d3d12.root_module.addIncludePath(nri.?.path("Source/Shared"));
            lib_nri_d3d12.linkLibC();

            mod_nri.linkLibrary(lib_nri_d3d12);

            if (nvapi) |_| {
                lib_nri_d3d12.root_module.addIncludePath(nvapi.?.path(""));

                const nvapi_obj_path: []const u8 = switch (target.result.cpu.arch) {
                    .x86_64 => "amd64/nvapi64.lib",
                    .x86 => "x86/nvapi.lib",
                    else => {
                        _ = b.addFail("Unresolved architecture for NVAPI");
                        return;
                    },
                };
                mod_nri.*.addObjectFile(nvapi.?.path(nvapi_obj_path));
            }

            if (amd_ags) |_| {
                lib_nri_d3d12.root_module.addIncludePath(amd_ags.?.path("ags_lib/inc"));
                lib_nri_d3d12.root_module.addCMacro("AGS_EXCLUDE_DIRECTX_11", "");
            }

            if (agility_sdk) |_| {
                lib_nri_d3d12.root_module.addIncludePath(agility_sdk.?.path("build/native/include"));
                lib_nri_d3d12.root_module.addCMacro("NRI_AGILITY_SDK_VERSION_MAJOR", NRI_AGILITY_SDK_VERSION_MAJOR);
            } else {
                lib_nri_d3d12.root_module.addCMacro("NRI_AGILITY_SDK_VERSION_MAJOR", "D3D12_SDK_VERSION");
            }

            if (d3d12_allocator) |_| {
                lib_nri_d3d12.root_module.addIncludePath(d3d12_allocator.?.path("include"));
                lib_nri_d3d12.root_module.addIncludePath(d3d12_allocator.?.path("src"));
            }

            //DX12_headers
            if (dx12_headers) |_| {
                lib_nri_d3d12.root_module.addIncludePath(dx12_headers.?.path("include"));
                lib_nri_shared.root_module.addIncludePath(dx12_headers.?.path("include"));
                translate_nri.addIncludePath(dx12_headers.?.path("include"));
            }

            //FFX
            if (ffx_sdk) |_| {
                lib_nri_d3d12.root_module.addIncludePath(ffx_sdk.?.path("ffx-api/include/ffx_api"));
            }
        }

        if (nri_options.EnableVKSupport.val) {
            const lib_nri_vk = b.addLibrary(.{
                .name = "lib_nri_vk",
                .root_module = b.addModule("nri_vk", .{
                    .target = target,
                    .optimize = optimize,
                    .sanitize_thread = false,
                    .sanitize_c = .off,
                }),
            });

            lib_nri_vk.root_module.addCSourceFiles(.{
                .root = nri.?.path(""),
                .files = &nri_vulkan_src,
                .flags = nri_joined_defines,
                .language = .cpp,
            });
            lib_nri_vk.root_module.addIncludePath(nri.?.path("Include"));
            lib_nri_vk.root_module.addIncludePath(nri.?.path("Source/Shared"));
            lib_nri_vk.linkLibC();

            mod_nri.linkLibrary(lib_nri_vk);

            if (vulkan_headers) |_| {
                lib_nri_vk.root_module.addIncludePath(vulkan_headers.?.path("include"));
                lib_nri_shared.root_module.addIncludePath(vulkan_headers.?.path("include"));
            }

            if (vulkan_allocator) |_| {
                lib_nri_vk.root_module.addIncludePath(vulkan_allocator.?.path("include"));
            }

            //FFX
            if (ffx_sdk) |_| {
                lib_nri_vk.root_module.addIncludePath(ffx_sdk.?.path("ffx-api/include/ffx_api"));
            }
        }

        if (nvtx) |_| {
            mod_nri.addIncludePath(nvtx.?.path("c/include"));
        }

        if (nri_options.EnableNISSdk.val) {
            mod_nri.addIncludePath(shadermake.?.path(""));
        }

        if (nri_options.EnableValidationSupport.val) {
            const lib_nri_validation = b.addLibrary(.{
                .name = "lib_nri_validation",
                .root_module = b.addModule("nri_validation", .{
                    .target = target,
                    .optimize = optimize,
                    .sanitize_thread = false,
                    .sanitize_c = .off,
                }),
            });

            lib_nri_validation.root_module.addCSourceFiles(.{
                .root = nri.?.path(""),
                .files = &nri_validation_src,
                .flags = nri_joined_defines,
                .language = .cpp,
            });
            lib_nri_validation.root_module.addIncludePath(nri.?.path("Include"));
            lib_nri_validation.root_module.addIncludePath(nri.?.path("Source/Shared"));
            lib_nri_validation.linkLibC();

            mod_nri.linkLibrary(lib_nri_validation);
        }
        if (nri_options.EnableNoneSupport.val) {
            const lib_nri_none = b.addLibrary(.{
                .name = "lib_nri_none",
                .root_module = b.addModule("nri_none", .{
                    .target = target,
                    .optimize = optimize,
                    .sanitize_thread = false,
                    .sanitize_c = .off,
                }),
            });

            lib_nri_none.root_module.addCSourceFiles(.{
                .root = nri.?.path(""),
                .files = &.{"Source/NONE/ImplNONE.cpp"},
                .flags = nri_joined_defines,
                .language = .cpp,
            });
            lib_nri_none.root_module.addIncludePath(nri.?.path("Include"));
            lib_nri_none.root_module.addIncludePath(nri.?.path("Source/Shared"));
            lib_nri_none.linkLibC();

            mod_nri.linkLibrary(lib_nri_none);
        }
    }

    //Agility SDK
    if (agility_sdk) |_| {
        const agility_sdk_bin_dir_path: []const u8 = switch (target.result.cpu.arch) {
            .aarch64 => "build/native/bin/arm64",
            .x86_64 => "build/native/bin/x64",
            .x86 => "build/native/bin/x86",
            else => {
                _ = b.addFail("Unresolved architecture for Agility SDK");
                return;
            },
        };
        b.addNamedLazyPath("agility_sdk_bin_dir", agility_sdk.?.path(agility_sdk_bin_dir_path));
    }

    //FFX
    if (ffx_sdk) |_| {
        const ffx_lib_path = ffx_sdk.?.path("PrebuiltSignedDLL");
        mod_nri.addLibraryPath(ffx_lib_path);

        if (nri_options.EnableD3D12Support.val) {
            mod_nri.linkSystemLibrary("amd_fidelityfx_dx12", .{ .needed = true, .preferred_link_mode = .static });
        }

        if (nri_options.EnableVKSupport.val) {
            mod_nri.linkSystemLibrary("amd_fidelityfx_vk", .{ .needed = true, .preferred_link_mode = .static });
        }
    }

    //XESS
    if (xess_sdk) |_| {
        //mod_nri.addObjectFile(xess_sdk.?.path("lib/libxess.lib"));
        mod_nri.addIncludePath(xess_sdk.?.path("inc/xess"));

        if (nri_options.EnableD3D12Support.val) {
            const xess_lib_path = xess_sdk.?.path("lib");
            const xess_bin_path = xess_sdk.?.path("bin");
            mod_nri.addLibraryPath(xess_lib_path);
            mod_nri.addLibraryPath(xess_bin_path);
            mod_nri.linkSystemLibrary("libxess", .{ .needed = true, .preferred_link_mode = .dynamic });

            const xess_dll_path = try std.fs.path.join(b.allocator, &.{ "bin", "libxess.dll" });
            installBinFile(b, null, xess_sdk.?.path(xess_dll_path), "libxess.dll");
        }
    }

    //NVAPI
    if (nvapi) |_| {
        const nvapi_obj_path: []const u8 = switch (target.result.cpu.arch) {
            .x86_64 => "amd64/nvapi64.lib",
            .x86 => "x86/nvapi.lib",
            else => {
                _ = b.addFail("Unresolved architecture for NVAPI");
                return;
            },
        };
        mod_nri.*.addObjectFile(nvapi.?.path(nvapi_obj_path));
        b.addNamedLazyPath("nvapi_hlsl_extension_include", nvapi.?.path(""));

        translate_nri.addIncludePath(nvapi.?.path(""));
    }

    //AMDAGS
    if (amd_ags) |_| {
        if (!nri_options.EnableD3D12Support.val) _ = b.addFail("Cannot reference AGS SDK without DirectX enabled");

        mod_nri.addLibraryPath(amd_ags.?.path("ags_lib/lib"));
        switch (target.result.cpu.arch) {
            .x86_64 => mod_nri.linkSystemLibrary("amd_ags_x64", .{ .needed = true, .preferred_link_mode = .static }),
            .x86 => mod_nri.linkSystemLibrary("amd_ags_x86", .{ .needed = true, .preferred_link_mode = .static }),
            else => {},
        }

        const amd_ags_dll_name = switch (target.result.cpu.arch) {
            .x86_64 => "amd_ags_x64.dll",
            .x86 => "amd_ags_x86.dll",
            else => unreachable,
        };
        const xess_dll_path = try std.fs.path.join(b.allocator, &.{ "ags_lib/lib", amd_ags_dll_name });
        installBinFile(b, null, amd_ags.?.path(xess_dll_path), amd_ags_dll_name);

        b.addNamedLazyPath("amd_ags_hlsl_extension_include", amd_ags.?.path(""));

        translate_nri.addIncludePath(amd_ags.?.path("ags_lib/inc"));
        translate_nri.defineCMacroRaw("AGS_EXCLUDE_DIRECTX_11");
    }

    //NGX
    var dlss_sr_dll_name: ?[]const u8 = null;
    var dlss_rr_dll_name: ?[]const u8 = null;
    var dlss_sr_dll_lazypath: ?std.Build.LazyPath = null;
    var dlss_rr_dll_lazypath: ?std.Build.LazyPath = null;
    if (ngx_sdk) |_| {
        const ngx_obj_path: []const u8 = switch (target.result.os.tag) {
            .windows => switch (optimize) {
                .Debug => "lib/Windows_x86_64/x64/nvsdk_ngx_s.lib",
                else => "lib/Windows_x86_64/x64/nvsdk_ngx_s.lib",
            },
            .linux => "lib/Linux_x86_64/libnvsdk_ngx.a",
            else => {
                _ = b.addFail("Unsupported platform for NGX");
                return;
            },
        };

        const dlss_dll_bin_path = b.fmt("lib/{s}/{s}/", .{
            switch (target.result.os.tag) {
                .windows => "Windows_x86_64",
                .linux => "Linux_x86_64",
                else => unreachable,
            },
            switch (optimize) {
                .Debug => "dev",
                else => "rel",
            },
        });

        dlss_sr_dll_name = switch (target.result.os.tag) {
            .windows => "nvngx_dlss.dll",
            .linux => "libnvidia-ngx-dlss.so." ++ NGX_VERSION,
            else => unreachable,
        };

        dlss_rr_dll_name = switch (target.result.os.tag) {
            .windows => "nvngx_dlssd.dll",
            .linux => "libnvidia-ngx-dlssd.so." ++ NGX_VERSION,
            else => unreachable,
        };

        const dlss_sr_dll_path = try std.mem.concat(b.allocator, u8, &.{ dlss_dll_bin_path, dlss_sr_dll_name.? });
        const dlss_rr_dll_path = try std.mem.concat(b.allocator, u8, &.{ dlss_dll_bin_path, dlss_rr_dll_name.? });

        dlss_sr_dll_lazypath = ngx_sdk.?.path(dlss_sr_dll_path);
        dlss_rr_dll_lazypath = ngx_sdk.?.path(dlss_rr_dll_path);

        mod_nri.addObjectFile(ngx_sdk.?.path(ngx_obj_path));
        mod_nri.addIncludePath(ngx_sdk.?.path("include"));
    }

    var shadermake_exe: ?*std.Build.Step.Compile = null;

    if (shadermake) |_| {
        shadermake_exe = b.addExecutable(.{
            .name = "shadermake",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .sanitize_thread = false,
                .sanitize_c = .off,
            }),
        });

        shadermake_exe.?.root_module.addCSourceFiles(.{
            .root = shadermake.?.path("ShaderMake"),
            .files = &.{
                "ShaderBlob.cpp",
                "ShaderMake.cpp",
            },
            .flags = if (target.result.os.tag == .windows) &.{
                "-DWIN32_LEAN_AND_MEAN",
                "-DNOMINMAX",
                "-D_CRT_SECURE_NO_WARNINGS",
                "-std=c++17",
            } else &.{},
            .language = .cpp,
        });

        shadermake_exe.?.root_module.addCSourceFiles(.{
            .root = shadermake.?.path("ShaderMake"),
            .files = &.{
                "argparse.h",
                "argparse.c",
            },
            .flags = if (target.result.os.tag == .windows) &.{
                "-DWIN32_LEAN_AND_MEAN",
                "-DNOMINMAX",
                "-D_CRT_SECURE_NO_WARNINGS",
            } else &.{},
            .language = .c,
        });

        shadermake_exe.?.linkLibC();

        switch (target.result.os.tag) {
            .windows => {},
            .macos => shadermake_exe.?.root_module.linkSystemLibrary("pthread", .{}),
            else => {
                shadermake_exe.?.root_module.linkSystemLibrary("stdc++fs", .{});
                shadermake_exe.?.root_module.linkSystemLibrary("pthread", .{});
            },
        }

        b.installArtifact(shadermake_exe.?);
    }

    //dlss
    if (dlss_sr_dll_lazypath) |_| {
        installBinFile(b, null, dlss_sr_dll_lazypath.?, dlss_sr_dll_name.?);
    }
    if (dlss_rr_dll_lazypath) |_| {
        installBinFile(b, null, dlss_rr_dll_lazypath.?, dlss_rr_dll_name.?);
    }

    const dxc = b.lazyDependency("dxc", .{});
    const nv_math = b.lazyDependency("nv_math", .{});

    if (shadermake_exe != null and dxc != null) {
        const dxc_path = switch (@import("builtin").target.cpu.arch) {
            .aarch64 => dxc.?.path("build/native/bin/arm64/dxc.exe"),
            .x86 => dxc.?.path("build/native/bin/x86/dxc.exe"),
            .x86_64 => dxc.?.path("build/native/bin/x64/dxc.exe"),
            else => unreachable,
        };

        const shader_output_path = "_Shaders"; //try std.fs.path.join(b.allocator, &.{ b.exe_dir, "_Shaders" });

        if (nri_options.EnableD3D12Support.val) {
            const run_d3d12_shared, const d3d12_shared_shader_dir = run_shadermake_command(.{
                .b = b,
                .shadermake = shadermake_exe.?,
                .target_api = .D3D12,
                .shader_compiler_path = dxc_path,
                .project_name = "NRI",
                .source_dir = nri.?.path("Shaders"),
                .shader_config_path = nri.?.path("Shaders/Shaders.cfg"),
                .output_path = shader_output_path,
                .include_paths = &.{
                    nri.?.path("Shaders"),
                    nri.?.path("Include"),
                },
                .s_reg_shift = "0",
                .b_reg_shift = "0",
                .u_reg_shift = "0",
                .t_reg_shift = "0",
                .header_blob = true,
            });

            b.getInstallStep().dependOn(&run_d3d12_shared.step);
            lib_nri_shared.step.dependOn(&run_d3d12_shared.step);
            lib_nri_shared.root_module.addIncludePath(d3d12_shared_shader_dir);
        }

        if (nri_options.EnableVKSupport.val) {
            const run_vulkan_shared, const vulkan_shared_shader_dir = run_shadermake_command(.{
                .b = b,
                .shadermake = shadermake_exe.?,
                .target_api = .Vulkan,
                .shader_compiler_path = dxc_path,
                .project_name = "NRI",
                .source_dir = nri.?.path("Shaders"),
                .shader_config_path = nri.?.path("Shaders/Shaders.cfg"),
                .output_path = shader_output_path,
                .include_paths = &.{
                    nri.?.path("Shaders"),
                    nri.?.path("Include"),
                },
                .s_reg_shift = "0",
                .b_reg_shift = "0",
                .u_reg_shift = "0",
                .t_reg_shift = "0",
                .header_blob = true,
            });

            b.getInstallStep().dependOn(&run_vulkan_shared.step);
            lib_nri_shared.step.dependOn(&run_vulkan_shared.step);
            lib_nri_shared.root_module.addIncludePath(vulkan_shared_shader_dir);
        }

        if (nri_samples) |_| {
            if (nv_math != null) {
                if (nri_options.EnableD3D12Support.val) {
                    const run_d3d12, _ = run_shadermake_command(.{
                        .b = b,
                        .shadermake = shadermake_exe.?,
                        .target_api = .D3D12,
                        .shader_compiler_path = dxc_path,
                        .project_name = "NRI_Samples",
                        .source_dir = nri_samples.?.path("Shaders"),
                        .shader_config_path = nri_samples.?.path("Shaders/Shaders.cfg"),
                        .output_path = shader_output_path,
                        .include_paths = &.{
                            nri_samples.?.path("Shaders"),
                            nv_math.?.path(""),
                            nri.?.path("Include"),
                        },
                        .s_reg_shift = "0",
                        .b_reg_shift = "32",
                        .u_reg_shift = "64",
                        .t_reg_shift = "128",
                        .header_blob = false,
                    });

                    b.getInstallStep().dependOn(&run_d3d12.step);
                }

                if (nri_options.EnableVKSupport.val) {
                    const run_vulkan, _ = run_shadermake_command(.{
                        .b = b,
                        .shadermake = shadermake_exe.?,
                        .target_api = .Vulkan,
                        .shader_compiler_path = dxc_path,
                        .project_name = "NRI_Samples",
                        .source_dir = nri_samples.?.path("Shaders"),
                        .shader_config_path = nri_samples.?.path("Shaders/Shaders.cfg"),
                        .output_path = shader_output_path,
                        .include_paths = &.{
                            nri_samples.?.path("Shaders"),
                            nv_math.?.path(""),
                            nri.?.path("Include"),
                        },
                        .s_reg_shift = "0",
                        .b_reg_shift = "32",
                        .u_reg_shift = "64",
                        .t_reg_shift = "128",
                        .header_blob = false,
                    });

                    b.getInstallStep().dependOn(&run_vulkan.step);
                }
            }
        }
    }

    //NRI Samples demo
    if (nri_samples) |_| {
        b.installDirectory(.{
            .install_dir = .bin,
            .install_subdir = "_Data",
            .source_dir = b.path("sample_resources"),
        });

        //Buffer Sample
        {
            const buffers_exe = b.addExecutable(.{
                .name = "NRISample_Buffers",
                .root_module = setup_sample_module(b, target, optimize, "mod_sample_buffers", nri.?, mod_nri, nri_joined_defines),
            });
            buffers_exe.addCSourceFile(.{
                .file = nri_samples.?.path("Source/Buffers.c"),
                .flags = &.{},
                .language = .c,
            });
            b.installArtifact(buffers_exe);
        }

        //Scene viewer sample
        {
            const scene_viewer_exe = b.addExecutable(.{
                .name = "NRISample_SceneViewer",
                .root_module = setup_sample_module(b, target, optimize, "mod_sample_buffers", nri.?, mod_nri, nri_joined_defines),
            });
            scene_viewer_exe.addCSourceFile(.{
                .file = nri_samples.?.path("Source/SceneViewer.cpp"),
                .flags = &.{"-std=c++17"},
                .language = .cpp,
            });

            b.installArtifact(scene_viewer_exe);
        }
    }
}

fn setup_sample_module(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, module_name: []const u8, nri: *std.Build.Dependency, mod_nri: *std.Build.Module, nri_joined_defines: [][]const u8) *std.Build.Module {
    const nri_framework = b.lazyDependency("nri_framework", .{});
    const glfw = b.lazyDependency("glfw", .{});
    const nv_math = b.lazyDependency("nv_math", .{});
    const imgui = b.lazyDependency("imgui", .{});
    const cgltf = b.lazyDependency("cgltf", .{});

    const mod_nri_framework = b.addModule(module_name, .{
        .target = target,
        .optimize = optimize,
        .sanitize_thread = false,
        .sanitize_c = .off,
    });
    //Framework source
    mod_nri_framework.addCSourceFiles(.{
        .root = nri_framework.?.path(""),
        .files = &nri_framework_src,
        .flags = &.{
            "-DWIN32_LEAN_AND_MEAN",
            "-DNOMINMAX",
            "-D_CRT_SECURE_NO_WARNINGS",
            "-std=c++17",
        },
        .language = .cpp,
    });
    mod_nri_framework.addIncludePath(nri_framework.?.path("Include"));
    mod_nri_framework.addIncludePath(nri.path("Include"));

    //detex
    mod_nri_framework.addCSourceFiles(.{
        .root = nri_framework.?.path(""),
        .files = &nri_framework_detex_src,
        .flags = &.{
            "-DWIN32_LEAN_AND_MEAN",
            "-DNOMINMAX",
            "-D_CRT_SECURE_NO_WARNINGS",
        },
        .language = .c,
    });
    mod_nri_framework.addIncludePath(nri_framework.?.path("External"));
    //glfw
    if (target.result.abi == .msvc) {
        mod_nri_framework.addLibraryPath(glfw.?.path("lib-vc2022"));
        mod_nri_framework.linkSystemLibrary("glfw3", .{ .preferred_link_mode = .static });
    }
    mod_nri_framework.addIncludePath(glfw.?.path("include"));
    //cgltf
    mod_nri_framework.addIncludePath(cgltf.?.path(""));
    //nri
    mod_nri_framework.addImport("nri", mod_nri);
    //imgui
    const lib_imgui = b.addLibrary(.{
        .name = "lib_imgui",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .sanitize_thread = false,
            .sanitize_c = .off,
        }),
    });
    lib_imgui.root_module.addCSourceFiles(.{
        .root = imgui.?.path(""),
        .files = &.{
            "imgui.cpp",
            "imgui_draw.cpp",
            "imgui_tables.cpp",
            "imgui_widgets.cpp",
        },
        .flags = nri_joined_defines,
        .language = .cpp,
    });
    lib_imgui.root_module.addIncludePath(imgui.?.path(""));
    lib_imgui.linkLibC();
    mod_nri_framework.addIncludePath(imgui.?.path(""));
    mod_nri_framework.linkLibrary(lib_imgui);

    //nv_math
    mod_nri_framework.addIncludePath(nv_math.?.path(""));
    return mod_nri_framework;
}

const ShaderTargetAPI = enum {
    D3D12,
    Vulkan,
};

const ShaderMakeCommandOptions = struct {
    b: *std.Build,
    shadermake: *std.Build.Step.Compile,
    target_api: ShaderTargetAPI,
    shader_compiler_path: std.Build.LazyPath,
    project_name: []const u8,
    source_dir: std.Build.LazyPath,
    shader_config_path: std.Build.LazyPath,
    output_path: []const u8,
    include_paths: []const std.Build.LazyPath,
    s_reg_shift: []const u8 = "0",
    b_reg_shift: []const u8 = "0",
    u_reg_shift: []const u8 = "0",
    t_reg_shift: []const u8 = "0",
    header_blob: bool = false,
};

fn run_shadermake_command(opt: ShaderMakeCommandOptions) struct { *std.Build.Step.Run, std.Build.LazyPath } {
    const run_shadermake = opt.b.addRunArtifact(opt.shadermake);
    run_shadermake.addArg("-p");
    run_shadermake.addArg(switch (opt.target_api) {
        .D3D12 => "DXIL",
        .Vulkan => "SPIRV",
    });
    run_shadermake.addArg("--compiler");
    run_shadermake.addFileArg(opt.shader_compiler_path);
    run_shadermake.addArg("--project");
    run_shadermake.addArg(opt.project_name);
    run_shadermake.addArg("--compactProgress");
    run_shadermake.addArg("--binary");
    run_shadermake.addArg("--flatten");
    run_shadermake.addArg("--stripReflection");
    run_shadermake.addArg("--WX");
    run_shadermake.addArg("--sRegShift");
    run_shadermake.addArg(opt.s_reg_shift);
    run_shadermake.addArg("--bRegShift");
    run_shadermake.addArg(opt.b_reg_shift);
    run_shadermake.addArg("--uRegShift");
    run_shadermake.addArg(opt.u_reg_shift);
    run_shadermake.addArg("--tRegShift");
    run_shadermake.addArg(opt.t_reg_shift);
    if (opt.header_blob) {
        run_shadermake.addArg("--headerBlob");
    }
    run_shadermake.addArg("--sourceDir");
    run_shadermake.addDirectoryArg(opt.source_dir);
    run_shadermake.addArg("--ignoreConfigDir");
    run_shadermake.addArg("-c");
    run_shadermake.addFileArg(opt.shader_config_path);
    run_shadermake.addArg("-o");
    const output_dir = run_shadermake.addOutputDirectoryArg(opt.output_path);
    for (opt.include_paths) |include_path| {
        run_shadermake.addArg("-I");
        run_shadermake.addDirectoryArg(include_path);
    }
    opt.b.installDirectory(.{
        .source_dir = output_dir,
        .install_dir = .bin,
        .install_subdir = opt.output_path,
    });
    //installBinFile(opt.b, &run_shadermake.step, output_dir, opt.output_path);

    return .{ run_shadermake, output_dir };
}

const nvapi_hlsl_files = [_][]const u8{
    "nvHLSLExtns.h",
    "nvHLSLExtnsInternal.h",
};

const nri_shared_src = [_][]const u8{
    //"Source/Shared/DeviceBase.h",
    //"Source/Shared/HelperInterface.h",
    //"Source/Shared/HelperInterface.hpp",
    //"Source/Shared/ImguiInterface.h",
    //"Source/Shared/ImguiInterface.hpp",
    //"Source/Shared/Lock.h",
    //"Source/Shared/NIS.h",
    "Source/Shared/Shared.cpp",
    //"Source/Shared/SharedExternal.h",
    //"Source/Shared/SharedExternal.hpp",
    //"Source/Shared/SharedLibrary.hpp",
    //"Source/Shared/StreamerInterface.h",
    //"Source/Shared/StreamerInterface.hpp",
    //"Source/Shared/UpscalerInterface.h",
    //"Source/Shared/UpscalerInterface.hpp",
};

const nri_d3d12_src = [_][]const u8{
    //"Source/D3D12/AccelerationStructureD3D12.h",
    //"Source/D3D12/AccelerationStructureD3D12.hpp",

    //"Source/D3D12/BufferD3D12.h",
    //"Source/D3D12/BufferD3D12.hpp",
    //"Source/D3D12/CommandAllocatorD3D12.h",
    //"Source/D3D12/CommandAllocatorD3D12.hpp",
    //"Source/D3D12/CommandBufferD3D12.h",
    //"Source/D3D12/CommandBufferD3D12.hpp",
    //"Source/D3D12/DescriptorD3D12.h",
    //"Source/D3D12/DescriptorD3D12.hpp",
    //"Source/D3D12/DescriptorPoolD3D12.h",
    //"Source/D3D12/DescriptorPoolD3D12.hpp",
    //"Source/D3D12/DescriptorSetD3D12.h",
    //"Source/D3D12/DescriptorSetD3D12.hpp",
    //"Source/D3D12/DeviceD3D12.h",
    //"Source/D3D12/DeviceD3D12.hpp",
    //"Source/D3D12/FenceD3D12.h",
    //"Source/D3D12/FenceD3D12.hpp",
    "Source/D3D12/ImplD3D12.cpp",
    //"Source/D3D12/MemoryAllocatorD3D12.h",
    //"Source/D3D12/MemoryD3D12.h",
    //"Source/D3D12/MemoryD3D12.hpp",
    //"Source/D3D12/MicromapD3D12.h",
    //"Source/D3D12/MicromapD3D12.hpp",
    //"Source/D3D12/PipelineCacheD3D12.h",
    //"Source/D3D12/PipelineCacheD3D12.hpp",
    //"Source/D3D12/PipelineD3D12.h",
    //"Source/D3D12/PipelineD3D12.hpp",
    //"Source/D3D12/PipelineLayoutD3D12.h",
    //"Source/D3D12/PipelineLayoutD3D12.hpp",
    //"Source/D3D12/QueryPoolD3D12.h",
    //"Source/D3D12/QueryPoolD3D12.hpp",
    //"Source/D3D12/QueueD3D12.h",
    //"Source/D3D12/QueueD3D12.hpp",
    //"Source/D3D12/SharedD3D12.h",
    //"Source/D3D12/SharedD3D12.hpp",
    //"Source/D3D12/SwapChainD3D12.h",
    //"Source/D3D12/SwapChainD3D12.hpp",
    //"Source/D3D12/TextureD3D12.h",
    //"Source/D3D12/TextureD3D12.hpp",
};

const nri_vulkan_src = [_][]const u8{
    //"Source/VK/AccelerationStructureVK.h",
    //"Source/VK/AccelerationStructureVK.hpp",
    //"Source/VK/BufferVK.h",
    //"Source/VK/BufferVK.hpp",
    //"Source/VK/CommandAllocatorVK.h",
    //"Source/VK/CommandAllocatorVK.hpp",
    //"Source/VK/CommandBufferVK.h",
    //"Source/VK/CommandBufferVK.hpp",
    //"Source/VK/ConversionVK.h",
    //"Source/VK/ConversionVK.hpp",
    //"Source/VK/DescriptorPoolVK.h",
    //"Source/VK/DescriptorPoolVK.hpp",
    //"Source/VK/DescriptorSetVK.h",
    //"Source/VK/DescriptorSetVK.hpp",
    //"Source/VK/DescriptorVK.h",
    //"Source/VK/DescriptorVK.hpp",
    //"Source/VK/DeviceVK.h",
    //"Source/VK/DeviceVK.hpp",
    //"Source/VK/DispatchTable.h",
    //"Source/VK/FenceVK.h",
    //"Source/VK/FenceVK.hpp",
    "Source/VK/ImplVK.cpp",
    //"Source/VK/MemoryAllocatorVK.h",
    //"Source/VK/MemoryVK.h",
    //"Source/VK/MemoryVK.hpp",
    //"Source/VK/MicromapVK.h",
    //"Source/VK/MicromapVK.hpp",
    //"Source/VK/PipelineCacheVK.h",
    //"Source/VK/PipelineCacheVK.hpp",
    //"Source/VK/PipelineLayoutVK.h",
    //"Source/VK/PipelineLayoutVK.hpp",
    //"Source/VK/PipelineVK.h",
    //"Source/VK/PipelineVK.hpp",
    //"Source/VK/QueryPoolVK.h",
    //"Source/VK/QueryPoolVK.hpp",
    //"Source/VK/QueueVK.h",
    //"Source/VK/QueueVK.hpp",
    //"Source/VK/SharedVK.h",
    //"Source/VK/SwapChainVK.h",
    //"Source/VK/SwapChainVK.hpp",
    //"Source/VK/TextureVK.h",
    //"Source/VK/TextureVK.hpp",
};

const nri_validation_src = [_][]const u8{
    //"Source/Validation/AccelerationStructureVal.h",
    //"Source/Validation/AccelerationStructureVal.hpp",
    //"Source/Validation/BufferVal.h",
    //"Source/Validation/BufferVal.hpp",
    //"Source/Validation/CommandAllocatorVal.h",
    //"Source/Validation/CommandAllocatorVal.hpp",
    //"Source/Validation/CommandBufferVal.h",
    //"Source/Validation/CommandBufferVal.hpp",
    //"Source/Validation/ConversionVal.hpp",
    //"Source/Validation/DescriptorPoolVal.h",
    //"Source/Validation/DescriptorPoolVal.hpp",
    //"Source/Validation/DescriptorSetVal.h",
    //"Source/Validation/DescriptorSetVal.hpp",
    //"Source/Validation/DescriptorVal.h",
    //"Source/Validation/DescriptorVal.hpp",
    //"Source/Validation/DeviceVal.h",
    //"Source/Validation/DeviceVal.hpp",
    //"Source/Validation/FenceVal.h",
    //"Source/Validation/FenceVal.hpp",
    "Source/Validation/ImplVal.cpp",
    //"Source/Validation/MemoryVal.h",
    //"Source/Validation/MemoryVal.hpp",
    //"Source/Validation/MicromapVal.h",
    //"Source/Validation/MicromapVal.hpp",
    //"Source/Validation/PipelineCacheVal.h",
    //"Source/Validation/PipelineCacheVal.hpp",
    //"Source/Validation/PipelineLayoutVal.h",
    //"Source/Validation/PipelineLayoutVal.hpp",
    //"Source/Validation/PipelineVal.h",
    //"Source/Validation/PipelineVal.hpp",
    //"Source/Validation/QueryPoolVal.h",
    //"Source/Validation/QueryPoolVal.hpp",
    //"Source/Validation/QueueVal.h",
    //"Source/Validation/QueueVal.hpp",
    //"Source/Validation/SharedVal.h",
    //"Source/Validation/SwapChainVal.h",
    //"Source/Validation/SwapChainVal.hpp",
    //"Source/Validation/TextureVal.h",
    //"Source/Validation/TextureVal.hpp",
};

const nri_framework_src = [_][]const u8{
    "Source/Camera.cpp",
    "Source/DebugAllocator.cpp",
    "Source/SampleBase.cpp",
    "Source/Timer.cpp",
    "Source/Utils.cpp",
};

const nri_framework_detex_src = [_][]const u8{
    "External/Detex/bits.c",
    "External/Detex/bptc-tables.c",
    "External/Detex/clamp.c",
    "External/Detex/convert.c",
    "External/Detex/dds.c",
    "External/Detex/decompress-bc.c",
    "External/Detex/decompress-bptc-float.c",
    "External/Detex/decompress-bptc.c",
    "External/Detex/decompress-eac.c",
    "External/Detex/decompress-etc.c",
    "External/Detex/decompress-rgtc.c",
    "External/Detex/division-tables.c",
    "External/Detex/file-info.c",
    "External/Detex/half-float.c",
    "External/Detex/hdr.c",
    "External/Detex/ktx.c",
    "External/Detex/misc.c",
    "External/Detex/stb.c",
    "External/Detex/texture.c",
};
