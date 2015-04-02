export  calculateMessage!,
        calculateForwardMessage!,
        calculateBackwardMessage!,
        execute,
        clearMessages!

function calculateMessage!(outbound_interface::Interface)
    # Calculate the outbound message on a specific interface by generating a schedule and executing it.
    # The resulting message is stored in the specified interface and returned.

    # Lock graph structure
    scheme = InferenceScheme()

    # Generate a message passing schedule
    printVerbose("Auto-generating message passing schedule...\n")
    schedule = generateSchedule!(outbound_interface, scheme)
    if verbose show(schedule) end

    # Execute the schedule
    printVerbose("\nExecuting above schedule...\n")
    execute(schedule, scheme)
    printVerbose("\ncalculateMessage!() done.")

    return outbound_interface.message
end

function pushRequiredInbound!(scheme::InferenceScheme, inbound_array::Array{Any,1}, node::Node, inbound_interface::Interface, outbound_interface::Interface)
    # Push the inbound message or marginal on inbound_interface, depending on the local graph structure.

    if !haskey(scheme.edge_to_subgraph, inbound_interface.edge) || !haskey(scheme.edge_to_subgraph, outbound_interface.edge)
        # Inbound and/or outbound edge is not explicitly listed in the scheme.
        # This is possible if one of those edges is internal to a composite node.
        # We will default to sum-product message passing, and consume the message on the inbound interface.
        # Composite nodes with explicit message passing will throw an error when one of their external interfaces belongs to a different subgraph, so it is safe to assume sum-product.
        try return push!(inbound_array, inbound_interface.partner.message) catch error("$(inbound_interface) is not connected to an edge.") end
    end

    # Should we require the inbound message or marginal?
    if is(subgraph(scheme, inbound_interface.edge), subgraph(scheme, outbound_interface.edge))
        # Both edges in same subgraph, require message
        try push!(inbound_array, inbound_interface.partner.message) catch error("$(inbound_interface) is not connected to an edge.") end
    else
        # A subgraph border is crossed, require marginal
        # The factor is the set of internal edges that are in the same subgraph
        try push!(inbound_array, qDistribution(scheme, node, inbound_interface.edge)) catch error("Missing approximate marginal for $(inbound_interface)") end
    end

end

# TODO: combination schedule_entry - scheme seems strange here, does scheme not envelope a schedule_entry (through subgraph)?
function execute(schedule_entry::ScheduleEntry, scheme::InferenceScheme)
    # Calculate the outbound message based on the inbound messages and the message calculation rule.
    # The resulting message is stored in the specified interface and is returned.

    outbound_interface = schedule_entry.interface
    # Preprocessing: collect all inbound messages and build the inbound_array
    node = outbound_interface.node
    inbound_array = Array(Any, 0) # inbound_array holds the inbound messages or marginals on every interface of the node (indexed by the interface id)
    outbound_interface_id = 0

    for j = 1:length(node.interfaces)
        interface = node.interfaces[j]
        if interface == outbound_interface
            outbound_interface_id = j
            push!(inbound_array, nothing) # This interface is outbound, push "nothing"
        else
            # Inbound message or marginal is required, push the required message/marginal to inbound_array
            pushRequiredInbound!(scheme, inbound_array, node, interface, outbound_interface)
        end
    end

    # Evaluate message calculation rule
    (rule, outbound_message) = schedule_entry.message_calculation_rule(node, outbound_interface_id, inbound_array...)

    # Post processing?
    if isdefined(schedule_entry, :post_processing)
        outbound_message = node.interfaces[outbound_interface_id].message = Message(schedule_entry.post_processing(outbound_message.payload))
    end

    # Print output for debugging
    if verbose && rule != :empty # Internal composite node calls to execute return :empty rule
        interface_name = (name(outbound_interface)!="") ? "$(name(outbound_interface))" : "$(outbound_interface_id)"
        postproc = (isdefined(schedule_entry, :post_processing)) ? string(schedule_entry.post_processing) : ""
        rule_field = "$(rule) $(postproc)"
        println("|$(pad(node.name, 15))|$(pad(interface_name,10))|$(pad(rule_field,30))|$(pad(format(outbound_message.payload),71))|")
    end

    return outbound_message
end

# Calculate forward/backward messages on an Edge
calculateForwardMessage!(edge::Edge) = calculateMessage!(edge.tail)
calculateBackwardMessage!(edge::Edge) = calculateMessage!(edge.head)

# Execute schedules
function execute(schedule::Any, scheme::InferenceScheme)
    # Execute a message passing schedule
    !isempty(schedule) || error("Cannot execute an empty schedule")

    # Print table header for execution log
    if verbose
        println("\n|     node      |interface |             rule             |                           calculated message                          |")
        println("|---------------|----------|------------------------------|-----------------------------------------------------------------------|")
    end

    for schedule_entry in schedule
        execute(schedule_entry, scheme)
    end
    # Return the last message in the schedule
    return schedule[end].interface.message
end

function execute(subgraph::Subgraph, scheme::InferenceScheme)
    printVerbose("Subgraph $(findfirst(scheme.factorization, subgraph)):")
    # Execute internal schedule
    execute(subgraph.internal_schedule, scheme)
    # Update q-distributions at external edges
    g_nodes = nodesConnectedToExternalEdges(subgraph)
    for node in g_nodes
        calculateQDistribution!(node, qFactor(scheme, node, subgraph), scheme)
    end
end

function execute(scheme::InferenceScheme)
    for subgraph in scheme.factorization
        execute(subgraph, scheme)
    end
end

function clearMessages!(node::Node)
    # Clear all outbound messages on the interfaces of node
    for interface in node.interfaces
        interface.message = nothing
    end
end

function clearMessages!(edge::Edge)
    # Clear all messages on an edge.
    edge.head.message = nothing
    edge.tail.message = nothing
end
