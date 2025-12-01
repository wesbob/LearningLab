## Issue
I have a report with this custom column that determines a group or single pickup. This was working fine until we added data for the next year. When I added a slicer to the report and switched over to 2025, it using data from 2024 AND 2025 to determine a group or single, and calculating wrong now. 

For example, in 2024, an assoicate picked up for multiple people which would be a group pick up calculated by my custom column--good deal. This year, the associate only picked up for themselves which should be a single. All data is in the same table so it has the associate's 2024 data with 2025 as well, so its now seeing the 2025 pickup as a group.

## Original DAX

```dax
PickupType = 
VAR ThisAssociate = Pickups[PrimaryAssociateId]
VAR OthersPicked =
    CALCULATE(
        COUNTROWS(Pickups),
        FILTER(
            ALLEXCEPT(Pickups, Pickups[PrimaryAssociateId]),
            Pickups[PrimaryAssociateId] = ThisAssociate
                && Pickups[PrimaryAssociateId] <> Pickups[SecondaryAssociateId])
    )
RETURN
IF(OthersPicked > 0, "GROUP", "SINGLE")
```

## The Reasoning
ALLEXCEPT(Pickups, Pickups[PrimaryAssociateId]) removes the Year filter, so 2024 “group” history bleeds into 2025.

## New DAX
```dax
PickupType =
VAR ThisAssociate = Pickups[PrimaryAssociateId]
VAR ThisYear =
    YEAR(Pickups[PickupDate])           -- or RELATED('Calendar'[Year]) if you use a Date table
VAR OthersPicked =
    CALCULATE(
        COUNTROWS(Pickups),
        FILTER(
            ALL(Pickups),               -- ignore row context, then reapply just what we want
            Pickups[PrimaryAssociateId] = ThisAssociate
            && YEAR(Pickups[PickupDate]) = ThisYear
            && Pickups[SecondaryAssociateId] <> ThisAssociate
            && NOT ISBLANK(Pickups[SecondaryAssociateId])
        )
    )
RETURN IF(OthersPicked > 0, "GROUP", "SINGLE")
```
