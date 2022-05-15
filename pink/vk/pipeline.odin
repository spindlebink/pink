/*
Pink Vulkan Renderer: Pipeline

Handles initialization and management of the render pipeline and swap chain.
*/

//+private
package pink_vk

import "core:math/bits"
import vk "vendor:vulkan"

VERTEX_SHADER_SPV_PATH :: "shaders/shader.vert.spv"
FRAGMENT_SHADER_SPV_PATH :: "shaders/shader.frag.spv"
CORE_SHADER_COUNT :: 2

/*
Initialize Pipeline

Initializes the renderer's pipeline, start to finish.
*/

init_pipeline :: proc(ctx: ^Context) -> Response {
	response := Response.OK
	
	if response = init_swap_chain(ctx); response != .OK do return response
	if response = init_render_pass(ctx); response != .OK do return response
	if response = init_graphics_pipeline(ctx); response != .OK do return response
	
	return response
}

/*
Deinitialize Pipeline

Destroys Vulkan objects associated with a pipeline.
*/

deinit_pipeline :: proc(ctx: ^Context) -> Response {
	for framebuffer in ctx.swap_chain.framebuffers do vk.DestroyFramebuffer(ctx.device, framebuffer, nil)
	vk.DestroyPipeline(ctx.device, ctx.graphics_pipeline, nil)
	vk.DestroyPipelineLayout(ctx.device, ctx.graphics_pipeline_layout, nil)
	vk.DestroyRenderPass(ctx.device, ctx.render_pass, nil)
	for image_view in ctx.swap_chain.image_views do vk.DestroyImageView(ctx.device, image_view, nil)
	vk.DestroySwapchainKHR(ctx.device, ctx.swap_chain.main, nil)
	return .OK
}

/*
Reinitialize Pipeline

Destroys pipeline and recreates it.
*/
reinit_pipeline :: proc(ctx: ^Context) -> Response {
	vk.DeviceWaitIdle(ctx.device)
	response := Response.OK
	if response = deinit_pipeline(ctx); response != .OK do return response
	if response = init_pipeline(ctx); response != .OK do return response
	return response
}

/*
Delete Pipeline

Deinitializes the render pipeline and frees all associated memory. The pipeline
cannot be reinitialized after this.
*/

delete_pipeline :: proc(ctx: ^Context) -> Response {
	response := deinit_pipeline(ctx)
	delete(ctx.swap_chain.images)
	delete(ctx.swap_chain.image_views)
	delete(ctx.swap_chain.framebuffers)
	return response
}


/*
Initialize Swap Chain

Initializes the renderer's swap chain.
*/

init_swap_chain :: proc(ctx: ^Context) -> Response {
	// First create the swap chain itself
	{
		swap_chain_support := get_device_swap_chain_support(ctx.physical_device); defer destroy_swap_chain_support(swap_chain_support)
		surface_format, present_mode, extent := select_swap_chain_features(&swap_chain_support)
	
		image_count := swap_chain_support.capabilities.minImageCount + 1
		if swap_chain_support.capabilities.maxImageCount > 0 && image_count > swap_chain_support.capabilities.maxImageCount {
			image_count = swap_chain_support.capabilities.maxImageCount
		}
	
		create_info := vk.SwapchainCreateInfoKHR{
			sType = .SWAPCHAIN_CREATE_INFO_KHR,
			surface = ctx.surface,
			minImageCount = image_count,
			imageFormat = surface_format.format,
			imageColorSpace = surface_format.colorSpace,
			imageExtent = extent,
			imageArrayLayers = 1,
			imageUsage = {.COLOR_ATTACHMENT},
			preTransform = swap_chain_support.capabilities.currentTransform,
			compositeAlpha = {.OPAQUE},
			presentMode = present_mode,
			clipped = true,
			oldSwapchain = vk.SwapchainKHR(0),
		}
	
		queue_families := get_queue_family_indices(ctx.physical_device)
		queue_indices := []u32{queue_families.graphics.(u32), queue_families.present.(u32)}
		if queue_families.graphics != queue_families.present {
			create_info.imageSharingMode = .CONCURRENT
			create_info.queueFamilyIndexCount = QUEUE_FAMILY_COUNT
			create_info.pQueueFamilyIndices = &queue_indices[0]
		} else {
			create_info.imageSharingMode = .EXCLUSIVE
		}
	
		if vk.CreateSwapchainKHR(ctx.device, &create_info, nil, &ctx.swap_chain.main) != .SUCCESS do return .VULKAN_CREATE_SWAP_CHAIN_FAILED

		resize(&ctx.swap_chain.images, int(image_count))
		vk.GetSwapchainImagesKHR(ctx.device, ctx.swap_chain.main, &image_count, raw_data(ctx.swap_chain.images))
	
		ctx.swap_chain.image_format = surface_format.format
		ctx.swap_chain.extent = extent
	}
	
	// Now initialize image views for each swap chain image
	{
		resize(&ctx.swap_chain.image_views, len(ctx.swap_chain.images))
		
		for image, i in ctx.swap_chain.images {
			create_info := vk.ImageViewCreateInfo{
				sType = .IMAGE_VIEW_CREATE_INFO,
				image = image,
				viewType = .D2,
				format = ctx.swap_chain.image_format,
				components = {.IDENTITY, .IDENTITY, .IDENTITY, .IDENTITY},
				subresourceRange = vk.ImageSubresourceRange{
					aspectMask = {.COLOR},
					baseMipLevel = 0,
					levelCount = 1,
					baseArrayLayer = 0,
					layerCount = 1,
				},
			}
			
			if vk.CreateImageView(ctx.device, &create_info, nil, &ctx.swap_chain.image_views[i]) != .SUCCESS do return .VULKAN_CREATE_IMAGE_VIEW_FAILED
		}
	}
	
	return .OK
}

/*
Select Swap Chain Features

Selects a surface format, present mode, and 2D extent from a swap chain support
structure.
*/

select_swap_chain_features :: proc(swap_chain_support: ^Swap_Chain_Support) -> (surface_format: vk.SurfaceFormatKHR, present_mode: vk.PresentModeKHR, extent: vk.Extent2D) {
	// Select surface format
	{
		found := false
		for available_format in &swap_chain_support.formats {
			if available_format.format == .B8G8R8A8_SRGB && available_format.colorSpace == .SRGB_NONLINEAR {
				surface_format = available_format
				found = true
				break
			}
		}
		if !found do surface_format = swap_chain_support.formats[0]
	}
	
	// Select present mode
	{
		found := false
		for available_mode in &swap_chain_support.present_modes {
			if available_mode == .MAILBOX {
				present_mode = available_mode
				found = true
				break
			}
		}
		if !found do present_mode = .FIFO
	}
	
	// Select extent
	{
		if swap_chain_support.capabilities.currentExtent.width != bits.U32_MAX {
			extent = swap_chain_support.capabilities.currentExtent
		} else {
			extent = vk.Extent2D{
				width = clamp(u32(ctx.drawable_width), swap_chain_support.capabilities.minImageExtent.width, swap_chain_support.capabilities.maxImageExtent.width),
				height = clamp(u32(ctx.drawable_height), swap_chain_support.capabilities.minImageExtent.height, swap_chain_support.capabilities.maxImageExtent.height),
			}
		}
	}
	
	return
}

/*
Initialize Render Pass

Initializes the renderer's render pass.
*/

init_render_pass :: proc(ctx: ^Context) -> Response {
	// First create render pass
	{
		color_attachment := vk.AttachmentDescription{
			format = ctx.swap_chain.image_format,
			samples = {._1},
			loadOp = .CLEAR,
			storeOp = .STORE,
			stencilLoadOp = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
			initialLayout = .UNDEFINED,
			finalLayout = .PRESENT_SRC_KHR,
		}
	
		color_attachment_ref := vk.AttachmentReference{
			attachment = 0,
			layout = .COLOR_ATTACHMENT_OPTIMAL,
		}
	
		render_pass_create_info := vk.RenderPassCreateInfo{
			sType = .RENDER_PASS_CREATE_INFO,
			attachmentCount = 1,
			pAttachments = &color_attachment,
			subpassCount = 1,
			pSubpasses = &vk.SubpassDescription{
				pipelineBindPoint = .GRAPHICS,
				colorAttachmentCount = 1,
				pColorAttachments = &color_attachment_ref,
			},
			dependencyCount = 1,
			pDependencies = &vk.SubpassDependency{
				srcSubpass = vk.SUBPASS_EXTERNAL,
				dstSubpass = 0,
				srcStageMask = {.COLOR_ATTACHMENT_OUTPUT},
				dstStageMask = {.COLOR_ATTACHMENT_OUTPUT},
				srcAccessMask = {},
				dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
			},
		}
	
		if vk.CreateRenderPass(ctx.device, &render_pass_create_info, nil, &ctx.render_pass) != .SUCCESS do return .VULKAN_CREATE_RENDER_PASS_FAILED
	}
	
	// Now create framebuffers
	{
		resize(&ctx.swap_chain.framebuffers, len(ctx.swap_chain.image_views))
		for image_view, i in &ctx.swap_chain.image_views {
			framebuffer_create_info := vk.FramebufferCreateInfo{
				sType = .FRAMEBUFFER_CREATE_INFO,
				renderPass = ctx.render_pass,
				attachmentCount = 1,
				pAttachments = &image_view,
				width = ctx.swap_chain.extent.width,
				height = ctx.swap_chain.extent.height,
				layers = 1,
			}
			if vk.CreateFramebuffer(ctx.device, &framebuffer_create_info, nil, &ctx.swap_chain.framebuffers[i]) != .SUCCESS do return .VULKAN_CREATE_FRAMEBUFFER_FAILED
		}
	}

	return .OK
}

/*
Initialize Graphics Pipeline
*/

init_graphics_pipeline :: proc(ctx: ^Context) -> Response {
	// First load shader modules
	vertex_source, fragment_source := #load(VERTEX_SHADER_SPV_PATH), #load(FRAGMENT_SHADER_SPV_PATH)
	sources := [CORE_SHADER_COUNT]^[]u32{cast(^[]u32) &vertex_source, cast(^[]u32) &fragment_source}
	modules: [CORE_SHADER_COUNT]vk.ShaderModule
	stage_create_infos: [CORE_SHADER_COUNT]vk.PipelineShaderStageCreateInfo
	
	for source, i in sources {
		create_info := vk.ShaderModuleCreateInfo{
			sType = .SHADER_MODULE_CREATE_INFO,
			codeSize = len(source),
			pCode = &source[0],
		}
		if vk.CreateShaderModule(ctx.device, &create_info, nil, &modules[i]) != .SUCCESS do return .VULKAN_CREATE_SHADER_MODULE_FAILED
		stage_create_infos[i] = vk.PipelineShaderStageCreateInfo{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {i == 0 ? .VERTEX : .FRAGMENT},
			module = modules[i],
			pName = "main",
		}
	}
	
	pipeline_layout_create_info := vk.PipelineLayoutCreateInfo{
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 0,
		pSetLayouts = nil,
		pushConstantRangeCount = 0,
		pPushConstantRanges = nil,
	}
	
	if vk.CreatePipelineLayout(ctx.device, &pipeline_layout_create_info, nil, &ctx.graphics_pipeline_layout) != .SUCCESS do return .VULKAN_CREATE_PIPELINE_LAYOUT_FAILED
	
	dynamic_states := []vk.DynamicState{.VIEWPORT, .LINE_WIDTH}
	vertex_binding_descriptions := VERTEX_INPUT_BINDING_DESCRIPTION
	vertex_attribute_descriptions := VERTEX_INPUT_ATTRIBUTE_DESCRIPTIONS
	
	pipeline_create_info := vk.GraphicsPipelineCreateInfo{
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		layout = ctx.graphics_pipeline_layout,
		renderPass = ctx.render_pass,
		stageCount = u32(len(stage_create_infos)),
		pStages = &stage_create_infos[0],
		pVertexInputState = &vk.PipelineVertexInputStateCreateInfo{
			sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
			vertexBindingDescriptionCount = 1,
			pVertexBindingDescriptions = &vertex_binding_descriptions,
			vertexAttributeDescriptionCount = u32(len(vertex_attribute_descriptions)),
			pVertexAttributeDescriptions = &vertex_attribute_descriptions[0],
		},
		pInputAssemblyState = &vk.PipelineInputAssemblyStateCreateInfo{
			sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
			topology = .TRIANGLE_LIST,
			primitiveRestartEnable = false,
		},
		pViewportState = &vk.PipelineViewportStateCreateInfo{
			sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
			viewportCount = 1,
			pViewports = &vk.Viewport{
				x = 0.0,
				y = 0.0,
				width = f32(ctx.swap_chain.extent.width),
				height = f32(ctx.swap_chain.extent.height),
			},
			scissorCount = 1,
			pScissors = &vk.Rect2D{
				offset = {0, 0},
				extent = ctx.swap_chain.extent,
			},
		},
		pRasterizationState = &vk.PipelineRasterizationStateCreateInfo{
			sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
			depthClampEnable = false,
			rasterizerDiscardEnable = false,
			polygonMode = .FILL,
			lineWidth = 1.0,
			cullMode = {.BACK},
			frontFace = .CLOCKWISE,
			depthBiasEnable = false,
			depthBiasConstantFactor = 0.0,
			depthBiasClamp = 0.0,
			depthBiasSlopeFactor = 0.0,
		},
		pMultisampleState = &vk.PipelineMultisampleStateCreateInfo{
			sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
			sampleShadingEnable = false,
			rasterizationSamples = {._1},
			minSampleShading = 1.0,
			pSampleMask = nil,
			alphaToCoverageEnable = false,
			alphaToOneEnable = false,
		},
		pColorBlendState = &vk.PipelineColorBlendStateCreateInfo{
			sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
			logicOpEnable = false,
			logicOp = .COPY,
			attachmentCount = 1,
			blendConstants = {0.0, 0.0, 0.0, 0.0},
			pAttachments = &vk.PipelineColorBlendAttachmentState{
				colorWriteMask = {.R, .G, .B, .A},
				blendEnable = false,
				srcColorBlendFactor = .SRC_ALPHA,
				dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
				colorBlendOp = .ADD,
				srcAlphaBlendFactor = .ONE,
				dstAlphaBlendFactor = .ZERO,
				alphaBlendOp = .ADD,
			},
		},
		pDynamicState = &vk.PipelineDynamicStateCreateInfo{
			sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
			// dynamicStateCount = 2,
			// pDynamicStates = &dynamic_states[0],
		},
	}
	
	if vk.CreateGraphicsPipelines(ctx.device, 0, 1, &pipeline_create_info, nil, &ctx.graphics_pipeline) != .SUCCESS do return .VULKAN_CREATE_GRAPHICS_PIPELINES_FAILED
	
	// If it all worked out, make sure we destroy the shader modules
	for module in modules do vk.DestroyShaderModule(ctx.device, module, nil)

	return .OK
}
