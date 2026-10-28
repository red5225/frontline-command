# Gameplay guide

## The map

The Atlas Theater is an original fictional country divided into 34 regions. Each region has a terrain label, supply rating, strategic value, and an initial controller. The map renderer generates cell-like province boundaries from the region centers and draws the country silhouette locally, so the game runs offline after the project is opened in Godot.

## Orders

Select a group marker on the map or use SELECT NEXT GROUP. ISSUE MOVEMENT ORDER enters destination-selection mode; click a region to send the selected group along the generated region network. Right-click is the shortcut. HOLD POSITION cancels the route.

## Simulation

The simulation can be paused or run at 1×, 2×, or 4× speed. Movement is timed per region. Groups that remain in a region can increase its control progress. Opposing groups in the same region enter an abstract control contest based on group strength, readiness, and supply; the contest has no weapon-specific rules.

Region control generates supply resources. Groups in controlled regions gradually recover supply; groups away from their administration network gradually lose it. The rival AI periodically selects a neighboring region and issues a route of its own.

## Objective

The first faction to administer at least 25 of the 34 regions completes the scenario. Use the live region counter and operations log to understand how control is changing.
