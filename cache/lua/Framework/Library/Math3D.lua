M3D = {}

local MAbs = math.abs
local MSqrt = math.sqrt
local MMod = math.fmod
local MFloor = math.floor
local MSin = math.sin
local MCos = math.cos
local MAsin = math.asin
local MAcos = math.acos
local MAtan = math.atan
local TransLoc = FVector(0.0, 0.0, 0.0)
local TransRot = FQuat(0.0, 0.0, 0.0, 1.0)
local TransScale = FVector(1.0, 1.0, 1.0)






-- region Common
local function MaintainAccuracy(X)
    return MFloor(X * 10000000.0 + 0.5) * 0.0000001
end
-- endregion Common






-- region Vec2
M3D.Vec2 = {
    __call = function(_, X, Y)
        return setmetatable({ X = X or 0, Y = Y or 0, Type = "Vec2" }, M3D.Vec2)
    end,

    __tostring = function(V)
        return string.format("(%.3f, %.3f)", V.X, V.Y)
    end,

    __eq = function(V1, V2)
        if (V1.Type ~= "Vec2") or (V2.Type ~= "Vec2") then
            print("Vec2 Equal Failed, Invalid Parameter !")
            return
        end

        return (MAbs(V1.X - V2.X) < 1e-10) and (MAbs(V1.Y - V2.Y) < 1e-10)
    end,

    __index = {
        Pack = function(V, X, Y)
            V.X = X or 0.0
            V.Y = Y or 0.0
        end,

        PackFromPCall = function(V, Res, X, Y)
            if (Res == true) then
                V.X = X or 0.0
                V.Y = Y or 0.0
            else
                V.X = 0.0
                V.Y = 0.0
            end
        end,

        Unpack = function(V)
            return V.X, V.Y
        end,

        Reset = function(V, X1, X2)
            if (V.Type ~= "Vec2") then
                print("Vec2 Reset Failed, Invalid Parameter !")
                return
            end

            if (type(X1) == "number") and (type(X2) == "number") then
                V.X = X1
                V.Y = X2
                return
            end

            if (X1 ~= nil) and (X1.Type == "Vec2") then
                V.X = X1.X
                V.Y = X1.Y
                return
            end

            V.X = 0.0
            V.Y = 0.0
        end,

        IsValid = function(V)
            if (V.Type ~= "Vec2") then
                return false
            end

            local StrX = tostring(V.X)
            if (StrX == 'nan') or (StrX == '-nan') or (StrX == 'inf') or (StrX == '-inf') then
                return false
            end

            local StrY = tostring(V.Y)
            if (StrY == 'nan') or (StrY == '-nan') or (StrY == 'inf') or (StrY == '-inf') then
                return false
            end

            return true
        end,

        IsNearlyZero = function(V, Tolerance)
            if (V.Type ~= "Vec2") then
                print("Vec2 IsNearlyZero Failed, Invalid Parameter !")
                return
            end

            if (type(Tolerance) ~= "number") then
                Tolerance = 1e-10
            end

            return (MAbs(V.X) <= Tolerance) and (MAbs(V.Y) <= Tolerance)
        end,

        Add = function(In1, In2, Out)
            if (In1.Type ~= "Vec2") or (In2.Type ~= "Vec2") or (Out.Type ~= "Vec2") then
                print("Vec2 Add Failed, Invalid Parameter !")
                return
            end

            Out.X = In1.X + In2.X
            Out.Y = In1.Y + In2.Y
        end,

        Sub = function(In1, In2, Out)
            if (In1.Type ~= "Vec2") or (In2.Type ~= "Vec2") or (Out.Type ~= "Vec2") then
                print("Vec2 Sub Failed, Invalid Parameter !")
                return
            end

            Out.X = In1.X - In2.X
            Out.Y = In1.Y - In2.Y
        end,

        Mul = function(In1, In2, Out)
            if (In1.Type ~= "Vec2") or (Out.Type ~= "Vec2") then
                print("Vec2 Mul Failed, Invalid Parameter !")
                return
            end

            if (type(In2) == "number") then
                Out.X = In1.X * In2
                Out.Y = In1.Y * In2
                return
            end

            if (In2 ~= nil) and (In2.Type == "Vec2") then
                Out.X = In1.X * In2.X
                Out.Y = In1.Y * In2.Y
                return
            end

            print("Vec2 Mul Failed, Invalid Parameter !")
        end,

        Div = function(In1, In2, Out)
            if (In1.Type ~= "Vec2") or (Out.Type ~= "Vec2") then
                print("Vec2 Div Failed, Invalid Parameter !")
                return
            end

            if (type(In2) == "number") then
                if (MAbs(In2) < 1e-10) then
                    print("Vec2 Div Failed, Divide Zero !")
                    return
                end

                Out.X = In1.X / In2
                Out.Y = In1.Y / In2
                return
            end

            if (In2 ~= nil) and (In2.Type == "Vec2") then
                if (MAbs(In2.X) < 1e-10) or (MAbs(In2.Y) < 1e-10) then
                    print("Vec2 Div Failed, Divide Zero !")
                    return
                end

                Out.X = In1.X / In2.X
                Out.Y = In1.Y / In2.Y
                return
            end

            print("Vec2 Div Failed, Invalid Parameter !")
        end,

        Size = function(V)
            if (V.Type ~= "Vec2") then
                print("Vec2 Size Failed, Invalid Parameter !")
                return
            end

            return MSqrt(V.X * V.X + V.Y * V.Y)
        end,

        SizeSquared = function(V)
            if (V.Type ~= "Vec2") then
                print("Vec2 Size Failed, Invalid Parameter !")
                return
            end

            return V.X * V.X + V.Y * V.Y
        end,

        Normalize = function(V)
            if (V.Type ~= "Vec2") then
                print("Vec2 Normalize Failed, Invalid Parameter !")
                return
            end

            local Size = MSqrt(V.X * V.X + V.Y * V.Y)
            if (MAbs(Size) > 1e-10) then
                V.X = V.X / Size
                V.Y = V.Y / Size
            end
        end,

        GetNormal = function(In, Out)
            if (In.Type ~= "Vec2") or (Out.Type ~= "Vec2") then
                print("Vec2 Normalize Failed, Invalid Parameter !")
                return
            end

            Out.X = In.X
            Out.Y = In.Y

            local Size = MSqrt(Out.X * Out.X + Out.Y * Out.Y)
            if (MAbs(Size) > 1e-10) then
                Out.X = Out.X / Size
                Out.Y = Out.Y / Size
            end
        end,

        Distance = function(V1, V2)
            if (V1.Type ~= "Vec2") or (V2.Type ~= "Vec2") then
                print("Vec2 Distance Failed, Invalid Parameter !")
                return
            end

            local X = V1.X - V2.X
            local Y = V1.Y - V2.Y

            return MSqrt(X * X + Y * Y)
        end,

        Dot = function(V1, V2)
            if (V1.Type ~= "Vec2") or (V2.Type ~= "Vec2") then
                print("Vec2 Dot Failed, Invalid Parameter !")
                return
            end

            return V1.X * V2.X + V1.Y * V2.Y
        end,

        Lerp = function(In1, In2, InTime, Out)
            if (In1.Type ~= "Vec2") or (In2.Type ~= "Vec2") or (Out.Type ~= "Vec2") or (type(InTime) ~= "number") then
                print("Vec2 Lerp Failed, Invalid Parameter !")
                return
            end

            Out.X = In1.X + (In2.X - In1.X) * InTime
            Out.Y = In1.Y + (In2.Y - In1.Y) * InTime
        end,

        Project = function(In1, In2, Out)
            if (In1.Type ~= "Vec2") or (In2.Type ~= "Vec2") or (Out.Type ~= "Vec2") then
                print("Vec2 Project Failed, Invalid Parameter !")
                return
            end

            Vec2Tmp1.X = In2.X
            Vec2Tmp1.Y = In2.Y

            local Size = MSqrt(Vec2Tmp1.X * Vec2Tmp1.X + Vec2Tmp1.Y * Vec2Tmp1.Y)
            if (MAbs(Size) > 1e-10) then
                Vec2Tmp1.X = Vec2Tmp1.X / Size
                Vec2Tmp1.Y = Vec2Tmp1.Y / Size
            end

            local Dot = In1.X * Vec2Tmp1.X + In1.Y * Vec2Tmp1.Y
            Out.X = In1.X * Dot
            Out.Y = In1.Y * Dot
        end
    }
}
setmetatable(M3D.Vec2, M3D.Vec2)
local Vec2Tmp1 = M3D.Vec2()
local Vec2Tmp2 = M3D.Vec2()
local Vec2Tmp3 = M3D.Vec2()
-- endregion Vec2






-- region Vec3
M3D.Vec3 = {
    __call = function(_, X, Y, Z)
        return setmetatable({ X = X or 0, Y = Y or 0, Z = Z or 0, Type = "Vec3" }, M3D.Vec3)
    end,

    __tostring = function(V)
        return string.format("(%.3f, %.3f, %.3f)", V.X, V.Y, V.Z)
    end,

    __eq = function(V1, V2)
        if (V1.Type ~= "Vec3") or (V2.Type ~= "Vec3") then
            print("Vec3 Equal Failed, Invalid Parameter !")
            return
        end

        return (MAbs(V1.X - V2.X) < 1e-10) and (MAbs(V1.Y - V2.Y) < 1e-10) and (MAbs(V1.Z - V2.Z) < 1e-10)
    end,

    __index = {
        Pack = function(V, X, Y, Z)
            V.X = X or 0.0
            V.Y = Y or 0.0
            V.Z = Z or 0.0
        end,

        PackFromPCall = function(V, Res, X, Y, Z)
            if (Res == true) then
                V.X = X or 0.0
                V.Y = Y or 0.0
                V.Z = Z or 0.0
            else
                V.X = 0.0
                V.Y = 0.0
                V.Z = 0.0
            end
        end,

        Unpack = function(V)
            return V.X, V.Y, V.Z
        end,

        Reset = function(V, X1, X2, X3)
            if (V.Type ~= "Vec3") then
                print("Vec3 Reset Failed, Invalid Parameter !")
                return
            end

            if (type(X1) == "number") and (type(X2) == "number") and (type(X3) == "number") then
                V.X = X1
                V.Y = X2
                V.Z = X3
                return
            end

            if (X1 ~= nil) and (X1.Type == "Vec3") then
                V.X = X1.X
                V.Y = X1.Y
                V.Z = X1.Z
                return
            end

            V.X = 0.0
            V.Y = 0.0
            V.Z = 0.0
        end,

        IsValid = function(V)
            if (V.Type ~= "Vec3") then
                return false
            end

            local StrX = tostring(V.X)
            if (StrX == 'nan') or (StrX == '-nan') or (StrX == 'inf') or (StrX == '-inf') then
                return false
            end

            local StrY = tostring(V.Y)
            if (StrY == 'nan') or (StrY == '-nan') or (StrY == 'inf') or (StrY == '-inf') then
                return false
            end

            local StrZ = tostring(V.Z)
            if (StrZ == 'nan') or (StrZ == '-nan') or (StrZ == 'inf') or (StrZ == '-inf') then
                return false
            end

            return true
        end,

        IsNearlyZero = function(V, Tolerance)
            if (V.Type ~= "Vec3") then
                print("Vec3 IsNearlyZero Failed, Invalid Parameter !")
                return
            end

            if (type(Tolerance) ~= "number") then
                Tolerance = 1e-10
            end

            return (MAbs(V.X) <= Tolerance) and (MAbs(V.Y) <= Tolerance) and (MAbs(V.Z) <= Tolerance)
        end,

        Add = function(In1, In2, Out)
            if (In1.Type ~= "Vec3") or (In2.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Vec3 Add Failed, Invalid Parameter !")
                return
            end

            Out.X = In1.X + In2.X
            Out.Y = In1.Y + In2.Y
            Out.Z = In1.Z + In2.Z
        end,

        Sub = function(In1, In2, Out)
            if (In1.Type ~= "Vec3") or (In2.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Vec3 Sub Failed, Invalid Parameter !")
                return
            end

            Out.X = In1.X - In2.X
            Out.Y = In1.Y - In2.Y
            Out.Z = In1.Z - In2.Z
        end,

        Mul = function(In1, In2, Out)
            if (In1.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Vec3 Mul Failed, Invalid Parameter !")
                return
            end

            if (type(In2) == "number") then
                Out.X = In1.X * In2
                Out.Y = In1.Y * In2
                Out.Z = In1.Z * In2
                return
            end

            if (In2 ~= nil) and (In2.Type == "Vec3") then
                Out.X = In1.X * In2.X
                Out.Y = In1.Y * In2.Y
                Out.Z = In1.Z * In2.Z
                return
            end

            print("Vec3 Mul Failed, Invalid Parameter !")
        end,

        Div = function(In1, In2, Out)
            if (In1.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Vec3 Div Failed, Invalid Parameter !")
                return
            end

            if (type(In2) == "number") then
                if (MAbs(In2) < 1e-10) then
                    print("Vec3 Div Failed, Divide Zero !")
                    return
                end

                Out.X = In1.X / In2
                Out.Y = In1.Y / In2
                Out.Z = In1.Z / In2
                return
            end

            if (In2 ~= nil) and (In2.Type == "Vec3") then
                if (MAbs(In2.X) < 1e-10) or (MAbs(In2.Y) < 1e-10) or (MAbs(In2.Z) < 1e-10) then
                    print("Vec3 Div Failed, Divide Zero !")
                    return
                end

                Out.X = In1.X / In2.X
                Out.Y = In1.Y / In2.Y
                Out.Z = In1.Z / In2.Z
                return
            end

            print("Vec3 Div Failed, Invalid Parameter !")
        end,

        Size = function(V)
            if (V.Type ~= "Vec3") then
                print("Vec3 Size Failed, Invalid Parameter !")
                return
            end

            return MSqrt(V.X * V.X + V.Y * V.Y + V.Z * V.Z)
        end,

        SizeSquared = function(V)
            if (V.Type ~= "Vec3") then
                print("Vec3 SizeSquared Failed, Invalid Parameter !")
                return
            end

            return V.X * V.X + V.Y * V.Y + V.Z * V.Z
        end,

        Size2D = function(V)
            if (V.Type ~= "Vec3") then
                print("Vec3 Size Failed, Invalid Parameter !")
                return
            end

            return MSqrt(V.X * V.X + V.Y * V.Y)
        end,

        SizeSquared2D = function(V)
            if (V.Type ~= "Vec3") then
                print("Vec3 Size Failed, Invalid Parameter !")
                return
            end

            return V.X * V.X + V.Y * V.Y
        end,

        Normalize = function(V)
            if (V.Type ~= "Vec3") then
                print("Vec3 Normalize Failed, Invalid Parameter !")
                return
            end

            local Size = MSqrt(V.X * V.X + V.Y * V.Y + V.Z * V.Z)
            if (MAbs(Size) > 1e-10) then
                V.X = V.X / Size
                V.Y = V.Y / Size
                V.Z = V.Z / Size
            end
        end,

        GetNormal = function(In, Out)
            if (In.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Vec3 Normalize Failed, Invalid Parameter !")
                return
            end

            local X = In.X
            local Y = In.Y
            local Z = In.Z

            local Size = MSqrt(X * X + Y * Y + Z * Z)
            if (MAbs(Size) > 1e-10) then
                Out.X = X / Size
                Out.Y = Y / Size
                Out.Z = Z / Size
            end
        end,

        GetNormal2D = function(In, Out)
            if (In.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Vec3 Normalize Failed, Invalid Parameter !")
                return
            end

            local X = In.X
            local Y = In.Y

            local Size = MSqrt(X * X + Y * Y)
            if (MAbs(Size) > 1e-10) then
                Out.X = X / Size
                Out.Y = Y / Size
                Out.Z = 0.0
            end
        end,

        Distance = function(V1, V2)
            if (V1.Type ~= "Vec3") or (V2.Type ~= "Vec3") then
                print("Vec3 Distance Failed, Invalid Parameter !")
                return 0
            end

            local X = V1.X - V2.X
            local Y = V1.Y - V2.Y
            local Z = V1.Z - V2.Z

            return MSqrt(X * X + Y * Y + Z * Z)
        end,

        Distance2D = function(V1, V2)
            if (V1.Type ~= "Vec3") or (V2.Type ~= "Vec3") then
                print("Vec3 Distance Failed, Invalid Parameter !")
                return 0
            end

            local X = V1.X - V2.X
            local Y = V1.Y - V2.Y

            return MSqrt(X * X + Y * Y)
        end,

        Dot = function(V1, V2)
            if (V1.Type ~= "Vec3") or (V2.Type ~= "Vec3") then
                print("Vec3 Dot Failed, Invalid Parameter !")
                return 0
            end

            return V1.X * V2.X + V1.Y * V2.Y + V1.Z * V2.Z
        end,

        Cross = function(In1, In2, Out)
            if (In1.Type ~= "Vec3") or (In2.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Vec3 Cross Failed, Invalid Parameter !")
                return
            end

            local X = In1.Y * In2.Z - In1.Z * In2.Y
            local Y = In1.Z * In2.X - In1.X * In2.Z
            local Z = In1.X * In2.Y - In1.Y * In2.X

            Out.X = X
            Out.Y = Y
            Out.Z = Z
        end,

        Lerp = function(In1, In2, InTime, Out)
            if (In1.Type ~= "Vec3") or (In2.Type ~= "Vec3") or (Out.Type ~= "Vec3") or (type(InTime) ~= "number") then
                print("Vec3 Lerp Failed, Invalid Parameter !")
                return
            end

            Out.X = In1.X + (In2.X - In1.X) * InTime
            Out.Y = In1.Y + (In2.Y - In1.Y) * InTime
            Out.Z = In1.Z + (In2.Z - In1.Z) * InTime
        end,

        Project = function(In1, In2, Out)
            if (In1.Type ~= "Vec3") or (In2.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Vec3 Project Failed, Invalid Parameter !")
                return
            end

            Vec3Tmp1.X = In2.X
            Vec3Tmp1.Y = In2.Y
            Vec3Tmp1.Z = In2.Z

            local Size = MSqrt(Vec3Tmp1.X * Vec3Tmp1.X + Vec3Tmp1.Y * Vec3Tmp1.Y + Vec3Tmp1.Z * Vec3Tmp1.Z)
            if (MAbs(Size) > 1e-10) then
                Vec3Tmp1.X = Vec3Tmp1.X / Size
                Vec3Tmp1.Y = Vec3Tmp1.Y / Size
                Vec3Tmp1.Z = Vec3Tmp1.Z / Size
            end

            local Dot = In1.X * Vec3Tmp1.X + In1.Y * Vec3Tmp1.Y + In1.Z * Vec3Tmp1.Z
            Out.X = In1.X * Dot
            Out.Y = In1.Y * Dot
            Out.Z = In1.Z * Dot
        end,

        PointPlaneProject = function(InPoint, InPlane, InPlaneN, OutPoint)
            if (InPoint.Type ~= "Vec3") or (InPlane.Type ~= "Vec3") or (InPlaneN.Type ~= "Vec3") or (OutPoint.Type ~= "Vec3") then
                print("Vec3 PointPlaneProject Failed, Invalid Parameter !")
                return
            end

            local X = InPoint.X - InPlane.X
            local Y = InPoint.Y - InPlane.Y
            local Z = InPoint.Z - InPlane.Z

            local Size = X * InPlaneN.X + Y * InPlaneN.Y + Z * InPlaneN.Z

            OutPoint.X = InPoint.X - Size * InPlaneN.X
            OutPoint.Y = InPoint.Y - Size * InPlaneN.Y
            OutPoint.Z = InPoint.Z - Size * InPlaneN.Z
        end,

        ToRotator = function(In, Out)
            if (In.Type ~= "Vec3") or (Out.Type ~= "Rotator") then
                print("Vec3 ToRotator Failed, Invalid Parameter !")
                return
            end

            local RToD = 57.29578

            Out.Roll = 0.0
            Out.Pitch = MaintainAccuracy(MAtan(In.Z, MSqrt(In.X * In.X + In.Y * In.Y)) * 57.29578)
            Out.Yaw = MaintainAccuracy(MAtan(In.Y, In.X) * 57.29578)
        end,

        ToQuat = function(In, Out)
            if (In.Type ~= "Vec3") or (Out.Type ~= "Quat") then
                print("Vec3 ToQuat Failed, Invalid Parameter !")
                return
            end

            local RadP = MaintainAccuracy(MAtan(In.Z, MSqrt(In.X * In.X + In.Y * In.Y))) * 0.5
            local SinP = MaintainAccuracy(MSin(RadP))
            local CosP = MaintainAccuracy(MCos(RadP))

            local RadY = MaintainAccuracy(MAtan(In.Y, In.X)) * 0.5
            local SinY = MaintainAccuracy(MSin(RadY))
            local CosY = MaintainAccuracy(MCos(RadY))

            Out.X = SinP * SinY
            Out.Y = SinP * CosY * -1.0
            Out.Z = CosP * SinY
            Out.W = CosP * CosY
        end
    }
}
setmetatable(M3D.Vec3, M3D.Vec3)
local Vec3Tmp1 = M3D.Vec3()
local Vec3Tmp2 = M3D.Vec3()
local Vec3Tmp3 = M3D.Vec3()
-- endregion Vec3






-- region Rotator
M3D.Rotator = {
    __call = function(_, Roll, Pitch, Yaw)
        local Result = setmetatable({ Roll = Roll or 0, Pitch = Pitch or 0, Yaw = Yaw or 0, Type = "Rotator" },
            M3D.Rotator)
        Result:Clamp()

        return Result
    end,

    __tostring = function(R)
        return string.format("(%.3f, %.3f, %.3f)", R.Roll, R.Pitch, R.Yaw)
    end,

    __eq = function(R1, R2)
        if (R1.Type ~= "Rotator") or (R2.Type ~= "Rotator") then
            print("Rotator Equal Failed, Invalid Parameter !")
            return
        end

        R1:Clamp()
        R2:Clamp()

        return (MAbs(R1.Roll - R2.Roll) < 1e-10) and (MAbs(R1.Pitch - R2.Pitch) < 1e-10) and
            (MAbs(R1.Yaw - R2.Yaw) < 1e-10)
    end,

    __index = {
        Pack = function(R, Roll, Pitch, Yaw)
            R.Roll = Roll or 0.0
            R.Pitch = Pitch or 0.0
            R.Yaw = Yaw or 0.0
        end,

        PackFromPCall = function(R, Res, Roll, Pitch, Yaw)
            if (Res == true) then
                R.Roll = Roll or 0.0
                R.Pitch = Pitch or 0.0
                R.Yaw = Yaw or 0.0
            else
                R.Roll = 0.0
                R.Pitch = 0.0
                R.Yaw = 0.0
            end
        end,

        Unpack = function(R)
            return R.Roll, R.Pitch, R.Yaw
        end,

        Reset = function(R, X1, X2, X3)
            if (R.Type ~= "Rotator") then
                print("Rotator Reset Failed, Invalid Parameter !")
                return
            end

            if (type(X1) == "number") and (type(X2) == "number") and (type(X3) == "number") then
                R.Roll = X1
                R.Pitch = X2
                R.Yaw = X3
                R:Clamp()
                return
            end

            if (X1 ~= nil) and (X1.Type == "Rotator") then
                R.Roll = X1.Roll
                R.Pitch = X1.Pitch
                R.Yaw = X1.Yaw
                return
            end

            R.Roll = 0.0
            R.Pitch = 0.0
            R.Yaw = 0.0
        end,

        IsValid = function(R)
            if (R.Type ~= "Rotator") then
                return false
            end

            local StrR = tostring(V.Roll)
            if (StrR == 'nan') or (StrR == '-nan') or (StrR == 'inf') or (StrR == '-inf') then
                return false
            end

            local StrP = tostring(V.Pitch)
            if (StrP == 'nan') or (StrP == '-nan') or (StrP == 'inf') or (StrP == '-inf') then
                return false
            end

            local StrY = tostring(V.Yaw)
            if (StrY == 'nan') or (StrY == '-nan') or (StrY == 'inf') or (StrY == '-inf') then
                return false
            end

            return true
        end,

        IsNearlyZero = function(R, Tolerance)
            if (R.Type ~= "Rotator") then
                print("Rotator Reset Failed, Invalid Parameter !")
                return
            end

            if (type(Tolerance) ~= "number") then
                Tolerance = 1e-10
            end

            return (MAbs(R.Roll) <= Tolerance) and (MAbs(R.Pitch) <= Tolerance) and (MAbs(R.Yaw) <= Tolerance)
        end,

        Add = function(In1, In2, Out)
            if (In1.Type ~= "Rotator") or (In2.Type ~= "Rotator") or (Out.Type ~= "Rotator") then
                print("Rotator Add Failed, Invalid Parameter !")
                return
            end

            Out.Roll = In1.Roll + In2.Roll
            Out.Pitch = In1.Pitch + In2.Pitch
            Out.Yaw = In1.Yaw + In2.Yaw

            Out:Clamp()
        end,

        Sub = function(In1, In2, Out)
            if (In1.Type ~= "Rotator") or (In2.Type ~= "Rotator") or (Out.Type ~= "Rotator") then
                print("Rotator Sub Failed, Invalid Parameter !")
                return
            end

            Out.Roll = In1.Roll - In2.Roll
            Out.Pitch = In1.Pitch - In2.Pitch
            Out.Yaw = In1.Yaw - In2.Yaw

            Out:Clamp()
        end,

        Mul = function(In1, In2, Out)
            if (In1.Type ~= "Rotator") or (Out.Type ~= "Rotator") then
                print("Rotator Mul Failed, Invalid Parameter !")
                return
            end

            if (type(In2) == "number") then
                Out.Roll = In1.Roll * In2
                Out.Pitch = In1.Pitch * In2
                Out.Yaw = In1.Yaw * In2
                Out:Clamp()
                return
            end

            if (In2 ~= nil) and (In2.Type == "Rotator") then
                Out.Roll = In1.Roll * In2.Roll
                Out.Pitch = In1.Pitch * In2.Pitch
                Out.Yaw = In1.Yaw * In2.Yaw
                Out:Clamp()
                return
            end

            print("Rotator Mul Failed, Invalid Parameter !")
        end,

        Div = function(In1, In2, Out)
            if (In1.Type ~= "Rotator") or (Out.Type ~= "Rotator") then
                print("Rotator Div Failed, Invalid Parameter !")
                return
            end

            if (type(In2) == "number") then
                if (MAbs(In2) < 1e-10) then
                    print("Rotator Div Failed, Divide Zero !")
                    return
                end

                Out.Roll = In1.Roll / In2
                Out.Pitch = In1.Pitch / In2
                Out.Yaw = In1.Yaw / In2
                Out:Clamp()
                return
            end

            if (In2 ~= nil) and (In2.Type == "Rotator") then
                if (MAbs(In2.Roll) < 1e-10) or (MAbs(In2.Pitch) < 1e-10) or (MAbs(In2.Yaw) < 1e-10) then
                    print("Rotator Div Failed, Divide Zero !")
                    return
                end

                Out.Roll = In1.Roll / In2.Roll
                Out.Pitch = In1.Pitch / In2.Pitch
                Out.Yaw = In1.Yaw / In2.Yaw
                Out:Clamp()
                return
            end

            print("Rotator Div Failed, Invalid Parameter !")
        end,

        -- 一般情况下，外界不需要调用
        Clamp = function(R)
            R.Roll = MMod(R.Roll, 360.0)
            if (R.Roll < 0.0) then
                R.Roll = R.Roll + 360.0
            end

            R.Pitch = MMod(R.Pitch, 360.0)
            if (R.Pitch < 0.0) then
                R.Pitch = R.Pitch + 360.0
            end

            R.Yaw = MMod(R.Yaw, 360.0)
            if (R.Yaw < 0.0) then
                R.Yaw = R.Yaw + 360.0
            end
        end,

        Normalize = function(R)
            if (R.Type ~= "Rotator") then
                print("Rotator Normalize Failed, Invalid Parameter !")
                return
            end

            R.Roll = MMod(R.Roll, 360.0)
            if (R.Roll - 180.0 > 1e-10) then
                R.Roll = R.Roll - 360.0
            end

            R.Pitch = MMod(R.Pitch, 360.0)
            if (R.Pitch - 180.0 > 1e-10) then
                R.Pitch = R.Pitch - 360.0
            end

            R.Yaw = MMod(R.Yaw, 360.0)
            if (R.Yaw - 180.0 > 1e-10) then
                R.Yaw = R.Yaw - 360.0
            end
        end,

        Lerp = function(In1, In2, InTime, Out)
            if (In1.Type ~= "Rotator") or (In2.Type ~= "Rotator") or (Out.Type ~= "Rotator") or (type(InTime) ~= "number") then
                print("Rotator Lerp Failed, Invalid Parameter !")
                return
            end

            In1:ToQuat(QuatTmp1)
            In2:ToQuat(QuatTmp2)

            QuatTmp1:SLerp(QuatTmp2, InTime, QuatTmp1)

            QuatTmp1:ToRotator(Out)
        end,

        ToVec3 = function(R, Out)
            if (R.Type ~= "Rotator") or (Out.Type ~= "Vec3") then
                print("Rotator ToVec3 Failed, Invalid Parameter !")
                return
            end

            R:Clamp()

            local DToR = 0.01745329

            local RadP = R.Pitch * DToR
            local SinP = MaintainAccuracy(MSin(RadP))
            local CosP = MaintainAccuracy(MCos(RadP))

            local RadY = R.Yaw * DToR
            local SinY = MaintainAccuracy(MSin(RadY))
            local CosY = MaintainAccuracy(MCos(RadY))

            Out.X = CosP * CosY
            Out.Y = CosP * SinY
            Out.Z = SinP
        end,

        ToQuat = function(R, Out)
            if (R.Type ~= "Rotator") or (Out.Type ~= "Quat") then
                print("Rotator ToQuat Failed, Invalid Parameter !")
                return
            end

            R:Clamp()

            local HalfDToR = 0.008726646

            local RadP = R.Pitch * HalfDToR
            local SinP = MaintainAccuracy(MSin(RadP))
            local CosP = MaintainAccuracy(MCos(RadP))

            local RadY = R.Yaw * HalfDToR
            local SinY = MaintainAccuracy(MSin(RadY))
            local CosY = MaintainAccuracy(MCos(RadY))

            local RadR = R.Roll * HalfDToR
            local SinR = MaintainAccuracy(MSin(RadR))
            local CosR = MaintainAccuracy(MCos(RadR))

            Out.X = CosR * SinP * SinY - SinR * CosP * CosY
            Out.Y = -CosR * SinP * CosY - SinR * CosP * SinY
            Out.Z = CosR * CosP * SinY - SinR * SinP * CosY
            Out.W = CosR * CosP * CosY + SinR * SinP * SinY
        end,

        ToMatrix = function(R)
            R:Clamp()

            local DToR = 0.01745329

            local RadP = R.Pitch * DToR
            local SinP = MaintainAccuracy(MSin(RadP))
            local CosP = MaintainAccuracy(MCos(RadP))

            local RadY = R.Yaw * DToR
            local SinY = MaintainAccuracy(MSin(RadY))
            local CosY = MaintainAccuracy(MCos(RadY))

            local RadR = R.Roll * DToR
            local SinR = MaintainAccuracy(MSin(RadR))
            local CosR = MaintainAccuracy(MCos(RadR))

            local M00 = CosP * CosY
            local M01 = CosP * SinY
            local M02 = SinP
            local M03 = 0.0

            local M10 = SinR * SinP * CosY - CosR * SinY
            local M11 = SinR * SinP * SinY + CosR * CosY
            local M12 = SinR * CosP * -1.0
            local M13 = 0.0

            local M20 = (CosR * SinP * CosY + SinR * SinY) * -1.0
            local M21 = CosY * SinR - CosR * SinP * SinY
            local M22 = CosR * CosP
            local M23 = 0.0

            local M30 = 0.0
            local M31 = 0.0
            local M32 = 0.0
            local M33 = 1.0

            return M00, M01, M02, M03, M10, M11, M12, M13, M20, M21, M22, M23, M30, M31, M32, M33
        end,

        ToInverseMatrix = function(R)
            R:Clamp()

            local DToR = 0.01745329

            local RadP = R.Pitch * DToR
            local SinP = MaintainAccuracy(MSin(RadP))
            local CosP = MaintainAccuracy(MCos(RadP))

            local RadY = R.Yaw * DToR
            local SinY = MaintainAccuracy(MSin(RadY))
            local CosY = MaintainAccuracy(MCos(RadY))

            local RadR = R.Roll * DToR
            local SinR = MaintainAccuracy(MSin(RadR))
            local CosR = MaintainAccuracy(MCos(RadR))

            local M00 = CosP * CosY
            local M10 = CosP * SinY
            local M20 = SinP
            local M30 = 0.0

            local M01 = SinR * SinP * CosY - CosR * SinY
            local M11 = SinR * SinP * SinY + CosR * CosY
            local M21 = SinR * CosP * -1.0
            local M31 = 0.0

            local M02 = (CosR * SinP * CosY + SinR * SinY) * -1.0
            local M12 = CosY * SinR - CosR * SinP * SinY
            local M22 = CosR * CosP
            local M32 = 0.0

            local M03 = 0.0
            local M13 = 0.0
            local M23 = 0.0
            local M33 = 1.0

            return M00, M01, M02, M03, M10, M11, M12, M13, M20, M21, M22, M23, M30, M31, M32, M33
        end,

        RotateVector = function(R, V, Out)
            if (R.Type ~= "Rotator") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Rotator RotateVector Failed, Invalid Parameter !")
                return
            end

            local M00, M01, M02, M03, M10, M11, M12, M13, M20, M21, M22, M23, M30, M31, M32, M33 = R:ToMatrix()

            local X = V.X
            local Y = V.Y
            local Z = V.Z

            Out.X = X * M00 + Y * M10 + Z * M20
            Out.Y = X * M01 + Y * M11 + Z * M21
            Out.Z = X * M02 + Y * M12 + Z * M22
        end,

        UnrotateVector = function(R, V, Out)
            if (R.Type ~= "Rotator") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Rotator UnrotateVector Failed, Invalid Parameter !")
                return
            end

            local M00, M01, M02, M03, M10, M11, M12, M13, M20, M21, M22, M23, M30, M31, M32, M33 = R:ToInverseMatrix()

            local X = V.X
            local Y = V.Y
            local Z = V.Z

            Out.X = X * M00 + Y * M10 + Z * M20
            Out.Y = X * M01 + Y * M11 + Z * M21
            Out.Z = X * M02 + Y * M12 + Z * M22
        end
    }
}
setmetatable(M3D.Rotator, M3D.Rotator)
local RotatorTmp1 = M3D.Rotator()
local RotatorTmp2 = M3D.Rotator()
local RotatorTmp3 = M3D.Rotator()
-- endregion Rotator






-- region Quat
M3D.Quat = {
    __call = function(_, X, Y, Z, W)
        local Result = setmetatable({ X = X or 0, Y = Y or 0, Z = Z or 0, W = W or 1, Type = "Quat" }, M3D.Quat)

        return Result
    end,

    __tostring = function(Q)
        return string.format("(%.3f, %.3f, %.3f, %.3f)", Q.X, Q.Y, Q.Z, Q.W)
    end,

    __eq = function(Q1, Q2)
        if (Q1.Type ~= "Quat") or (Q2.Type ~= "Quat") then
            print("Quat Equal Failed, Invalid Parameter !")
            return
        end

        return (MAbs(Q1.X - Q2.X) < 1e-10) and (MAbs(Q1.Y - Q2.Y) < 1e-10) and (MAbs(Q1.Z - Q2.Z) < 1e-10) and
            (MAbs(Q1.W - Q2.W) < 1e-10)
    end,

    __index = {
        Pack = function(Q, X, Y, Z, W)
            Q.X = X or 0.0
            Q.Y = Y or 0.0
            Q.Z = Z or 0.0
            Q.W = W or 0.0
        end,

        PackFromPCall = function(Q, Res, X, Y, Z, W)
            if (Res == true) then
                Q.X = X or 0.0
                Q.Y = Y or 0.0
                Q.Z = Z or 0.0
                Q.W = W or 0.0
            else
                Q.X = 0.0
                Q.Y = 0.0
                Q.Z = 0.0
                Q.W = 0.0
            end
        end,

        Unpack = function(Q)
            return Q.X, Q.Y, Q.Z, Q.W
        end,

        GetAngle = function(Q)
            if (Q.Type ~= "Quat") then
                print("Quat GetAngle Failed, Invalid Parameter !")
                return
            end

            return MaintainAccuracy(MAcos(Q.W)) * 2.0
        end,

        Reset = function(Q, X1, X2, X3, X4)
            if (Q.Type ~= "Quat") then
                print("Quat Reset Failed, Invalid Parameter !")
                return
            end

            if (type(X1) == "number") and (type(X2) == "number") and (type(X3) == "number") and (type(X4) == "number") then
                Q.X = X1
                Q.Y = X2
                Q.Z = X3
                Q.W = X4
                return
            end

            if (X1 ~= nil) and (X1.Type == "Quat") then
                Q.X = X1.X
                Q.Y = X1.Y
                Q.Z = X1.Z
                Q.W = X1.W
                return
            end

            Q.X = 0.0
            Q.Y = 0.0
            Q.Z = 0.0
            Q.W = 1.0
        end,

        IsValid = function(Q)
            if (Q.Type ~= "Quat") then
                return false
            end

            local StrX = tostring(V.X)
            if (StrX == 'nan') or (StrX == '-nan') or (StrX == 'inf') or (StrX == '-inf') then
                return false
            end

            local StrY = tostring(V.Y)
            if (StrY == 'nan') or (StrY == '-nan') or (StrY == 'inf') or (StrY == '-inf') then
                return false
            end

            local StrZ = tostring(V.Z)
            if (StrZ == 'nan') or (StrZ == '-nan') or (StrZ == 'inf') or (StrZ == '-inf') then
                return false
            end

            local StrW = tostring(V.W)
            if (StrW == 'nan') or (StrW == '-nan') or (StrW == 'inf') or (StrW == '-inf') then
                return false
            end

            return true
        end,

        IsIdentity = function(Q, Tolerance)
            if (Q.Type ~= "Quat") then
                print("Quat Reset Failed, Invalid Parameter !")
                return
            end

            if (type(Tolerance) ~= "number") then
                Tolerance = 1e-10
            end

            return (MAbs(Q.X) <= Tolerance) and (MAbs(Q.Y) <= Tolerance) and (MAbs(Q.Z) <= Tolerance) and
                (MAbs(Q.W - 1.0) <= Tolerance)
        end,

        Add = function(In1, In2, Out)
            if (In1.Type ~= "Quat") or (In2.Type ~= "Quat") or (Out.Type ~= "Quat") then
                print("Quat Add Failed, Invalid Parameter !")
                return
            end

            Out.X = In1.X + In2.X
            Out.Y = In1.Y + In2.Y
            Out.Z = In1.Z + In2.Z
            Out.W = In1.W + In2.W
        end,

        Sub = function(In1, In2, Out)
            if (In1.Type ~= "Quat") or (In2.Type ~= "Quat") or (Out.Type ~= "Quat") then
                print("Quat Sub Failed, Invalid Parameter !")
                return
            end

            Out.X = In1.X - In2.X
            Out.Y = In1.Y - In2.Y
            Out.Z = In1.Z - In2.Z
            Out.W = In1.W - In2.W
        end,

        Mul = function(In1, In2, Out)
            if (In1.Type ~= "Quat") or (In2.Type ~= "Quat") or (Out.Type ~= "Quat") then
                print("Quat Mul Failed, Invalid Parameter !")
                return
            end

            local X = In1.W * In2.X + In1.X * In2.W + In1.Y * In2.Z - In1.Z * In2.Y
            local Y = In1.W * In2.Y - In1.X * In2.Z + In1.Y * In2.W + In1.Z * In2.X
            local Z = In1.W * In2.Z + In1.X * In2.Y - In1.Y * In2.X + In1.Z * In2.W
            local W = In1.W * In2.W - In1.X * In2.X - In1.Y * In2.Y - In1.Z * In2.Z

            Out.X = X
            Out.Y = Y
            Out.Z = Z
            Out.W = W
        end,

        Scale = function(In1, In2, Out)
            if (In1.Type ~= "Quat") or (Out.Type ~= "Quat") then
                print("Quat Scale Failed, Invalid Parameter !")
                return
            end

            if (type(In2) == "number") then
                Out.X = In1.X * In2
                Out.Y = In1.Y * In2
                Out.Z = In1.Z * In2
                Out.W = In1.W * In2
                return
            end

            print("Quat Scale Failed, Invalid Parameter !")
        end,

        Normalize = function(Q)
            if (Q.Type ~= "Quat") then
                print("Quat Normalize Failed, Invalid Parameter !")
                return
            end

            local Square = Q.X * Q.X + Q.Y * Q.Y + Q.Z * Q.Z + Q.W * Q.W
            if (Square > 1e-4) then
                local Scale = 1.0 / MSqrt(Square)

                Q.X = Q.X * Scale
                Q.Y = Q.Y * Scale
                Q.Z = Q.Z * Scale
                Q.W = Q.W * Scale
            end
        end,

        SLerp = function(In1, In2, InTime, Out)
            if (In1.Type ~= "Quat") or (In2.Type ~= "Quat") or (Out.Type ~= "Quat") or (type(InTime) ~= "number") then
                print("Quat Lerp Failed, Invalid Parameter !")
                return
            end

            local RawCosom = In1.X * In2.X + In1.Y * In2.Y + In1.Z * In2.Z + In1.W * In2.W
            local Cosom = (RawCosom >= 0.0) and RawCosom or -RawCosom

            local Scale0 = 0.0
            local Scale1 = 0.0

            if (Cosom < 0.9999) then
                local Omega = MaintainAccuracy(MAcos(Cosom))
                local InvSin = 1.0 / MaintainAccuracy(MSin(Omega))

                Scale0 = MaintainAccuracy(MSin((1.0 - InTime) * Omega)) * InvSin
                Scale1 = MaintainAccuracy(MSin(InTime * Omega)) * InvSin
            else
                Scale0 = 1.0 - InTime
                Scale1 = InTime
            end

            Scale1 = (RawCosom >= 0.0) and Scale1 or -Scale1

            Out.X = Scale0 * In1.X + Scale1 * In2.X
            Out.Y = Scale0 * In1.Y + Scale1 * In2.Y
            Out.Z = Scale0 * In1.Z + Scale1 * In2.Z
            Out.W = Scale0 * In1.W + Scale1 * In2.W
        end,

        ToVec3 = function(In, Out)
            if (In.Type ~= "Quat") or (Out.Type ~= "Vec3") then
                print("Quat ToVec3 Failed, Invalid Parameter !")
                return
            end

            Vec3Tmp3:Reset(1.0, 0.0, 0.0)

            In:RotateVector(Vec3Tmp3, Out)
        end,

        ToRotator = function(In, Out)
            if (In.Type ~= "Quat") or (Out.Type ~= "Rotator") then
                print("Quat ToRotator Failed, Invalid Parameter !")
                return
            end

            local RToD = 57.29578

            local SingularityTest = In.Z * In.X - In.W * In.Y
            local YawY = 2.0 * (In.W * In.Z + In.X * In.Y)
            local YawX = In.Y * In.Y + In.Z * In.Z
            YawX = 1.0 - 2.0 * YawX

            if (SingularityTest < -0.4999995) then
                Out.Pitch = -90.0
                Out.Yaw = MaintainAccuracy(MAtan(YawY, YawX) * 57.29578)
                Out.Roll = -Out.Yaw - 2.0 * MaintainAccuracy(MAtan(In.X, In.W) * 57.29578)
            elseif (SingularityTest > 0.4999995) then
                Out.Pitch = 90.0
                Out.Yaw = MaintainAccuracy(MAtan(YawY, YawX) * 57.29578)
                Out.Roll = Out.Yaw - 2.0 * MaintainAccuracy(MAtan(In.X, In.W) * 57.29578)
            else
                Out.Pitch = MaintainAccuracy(2.0 * SingularityTest * 57.29578)
                Out.Yaw = MaintainAccuracy(MAtan(YawY, YawX) * 57.29578)
                Out.Roll = MaintainAccuracy(MAtan(-2.0 * (In.W * In.X + In.Y * In.Z),
                    (1.0 - 2.0 * (In.X * In.X + In.Y * In.Y))) * 57.29578)
            end

            Out:Clamp()
        end,

        RotateVector = function(Q, V, Out)
            if (Q.Type ~= "Quat") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Quat RotateVector Failed, Invalid Parameter !")
                return
            end

            local QX = Q.X
            local QY = Q.Y
            local QZ = Q.Z
            local QW = Q.W

            local VX = V.X
            local VY = V.Y
            local VZ = V.Z

            local X = (QY * VZ - QZ * VY) * 2.0
            local Y = (QZ * VX - QX * VZ) * 2.0
            local Z = (QX * VY - QY * VX) * 2.0

            Out.X = VX + (QY * Z - QZ * Y) + X * QW
            Out.Y = VY + (QZ * X - QX * Z) + Y * QW
            Out.Z = VZ + (QX * Y - QY * X) + Z * QW
        end,

        UnrotateVector = function(Q, V, Out)
            if (Q.Type ~= "Quat") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Quat UnrotateVector Failed, Invalid Parameter !")
                return
            end

            local QX = -Q.X
            local QY = -Q.Y
            local QZ = -Q.Z
            local QW = Q.W

            local VX = V.X
            local VY = V.Y
            local VZ = V.Z

            local X = (QY * VZ - QZ * VY) * 2.0
            local Y = (QZ * VX - QX * VZ) * 2.0
            local Z = (QX * VY - QY * VX) * 2.0

            Out.X = VX + (QY * Z - QZ * Y) + X * QW
            Out.Y = VY + (QZ * X - QX * Z) + Y * QW
            Out.Z = VZ + (QX * Y - QY * X) + Z * QW
        end,

        FindBetweenVectors = function(In1, In2, Out)
            if (In1.Type ~= "Vec3") or (In2.Type ~= "Vec3") or (Out.Type ~= "Quat") then
                print("Quat FindBetweenVectors Failed, Invalid Parameter !")
                return
            end

            local NormAB = MSqrt(In1:SizeSquared() * In2:SizeSquared())
            local W = NormAB + In1:Dot(In2)

            if (W >= 1e-6 * NormAB) then
                Out.X = In1.Y * In2.Z - In1.Z * In2.Y
                Out.Y = In1.Z * In2.X - In1.X * In2.Z
                Out.Z = In1.X * In2.Y - In1.Y * In2.X
                Out.W = W
            else
                if (MAbs(In1.X) > MAbs(In1.Y)) then
                    Out.X = -In1.Z
                    Out.Y = 0.0
                    Out.Z = In1.X
                    Out.W = 0.0
                else
                    Out.X = 0.0
                    Out.Y = -In1.Z
                    Out.Z = In1.Y
                    Out.W = 0.0
                end
            end

            Out:Normalize()
        end
    }
}
setmetatable(M3D.Quat, M3D.Quat)
local QuatTmp1 = M3D.Quat()
local QuatTmp2 = M3D.Quat()
local QuatTmp3 = M3D.Quat()
-- endregion Quat






-- region Transform
M3D.Transform = {
    __call = function(_, X1, X2, X3)
        local Result = setmetatable(
            { Translation = M3D.Vec3(), Rotation = M3D.Quat(), Scale3D = M3D.Vec3(1.0, 1.0, 1.0), Type = "Transform" },
            M3D.Transform)

        if (X1 ~= nil) and (X1.Type == "Vec3") then
            Result.Translation:Reset(X1)
        end

        if (X2 ~= nil) then
            if (X2.Type == "Quat") then
                Result.Rotation:Reset(X2)
            end

            if (X2.Type == "Rotator") then
                X2:ToQuat(Result.Rotation)
            end
        end

        if (X3 ~= nil) and (X3.Type == "Vec3") then
            Result.Scale3D:Reset(X3)
        end

        return Result
    end,

    __tostring = function(T)
        return string.format("Loc = %s, Rot = %s, Scale = %s", T.Translation, T.Rotation, T.Scale3D)
    end,

    __eq = function(T1, T2)
        if (T1.Type ~= "Transform") or (T2.Type ~= "Transform") then
            print("Transform Equal Failed, Invalid Parameter !")
            return
        end

        return (T1.Translation == T2.Translation) and (T1.Rotation == T2.Rotation) and (T1.Scale3D == T2.Scale3D)
    end,

    __index = {
        Pack = function(T, LX, LY, LZ, RX, RY, RZ, RW, SX, SY, SZ)
            T.Translation:Pack(LX, LY, LZ)
            T.Rotation:Pack(RX, RY, RZ, RW)
            T.Scale3D:Pack(SX, SY, SZ)
        end,

        PackFromPCall = function(T, Res, LX, LY, LZ, RX, RY, RZ, RW, SX, SY, SZ)
            if (Res == true) then
                T.Translation:Pack(LX, LY, LZ)
                T.Rotation:Pack(RX, RY, RZ, RW)
                T.Scale3D:Pack(SX, SY, SZ)
            else
                T.Translation:Pack(0.0, 0.0, 0.0)
                T.Rotation:Pack(0.0, 0.0, 0.0, 1.0)
                T.Scale3D:Pack(1.0, 1.0, 1.0)
            end
        end,

        Unpack = function(T)
            local Loc = T.Translation
            local Rot = T.Rotation
            local S3D = T.Scale3D

            return Loc.X, Loc.Y, Loc.Z, Rot.X, Rot.Y, Rot.Z, Rot.W, S3D.X, S3D.Y, S3D.Z
        end,

        IsValid = function(T)
            if (T.Type ~= "Transform") then
                return false
            end

            if (T.Translation:IsValid() == false) then
                return false
            end

            if (T.Rotation:IsValid() == false) then
                return false
            end

            if (T.Scale3D:IsValid() == false) then
                return false
            end

            return true
        end,

        Reset = function(T, X1, X2, X3)
            if (T.Type ~= "Transform") then
                print("Transform Reset Failed, Invalid Parameter !")
                return
            end

            if (X1 ~= nil) then
                if (X1.Type == "Transform") then
                    T.Translation:Reset(X1.Translation)
                    T.Rotation:Reset(X1.Rotation)
                    T.Scale3D:Reset(X1.Scale3D)
                    return
                elseif (X1.Type == "Vec3") then
                    T.Translation:Reset(X1)
                else
                    T.Translation:Reset()
                end
            else
                T.Translation:Reset()
            end

            if (X2 ~= nil) then
                if (X2.Type == "Rotator") then
                    X2:ToQuat(T.Rotation)
                elseif (X2.Type == "Quat") then
                    T.Rotation:Reset(X2)
                else
                    T.Rotation:Reset()
                end
            else
                T.Rotation:Reset()
            end

            if (X3 ~= nil) and (X3.Type == "Vec3") then
                T.Scale3D:Reset(X3)
            else
                T.Scale3D:Reset(1.0, 1.0, 1.0)
            end
        end,

        Mul = function(In1, In2, Out)
            if (In1.Type ~= "Transform") or (In2.Type ~= "Transform") or (Out.Type ~= "Transform") then
                print("Transform Mul Failed, Invalid Parameter !")
                return
            end

            if (In1.Scale3D:IsNearlyZero() == true) or (In2.Scale3D:IsNearlyZero() == true) then
                print("Transform Mul Failed, Scale3D Is Nearly Zero !")
                return
            end

            -- 计算朝向
            In2.Rotation:Mul(In1.Rotation, QuatTmp1)

            -- 计算位置
            In2.Scale3D:Mul(In1.Translation, Vec3Tmp3)
            In2.Rotation:RotateVector(Vec3Tmp3, Vec3Tmp3)
            In2.Translation:Add(Vec3Tmp3, Vec3Tmp3)

            -- 计算缩放
            In1.Scale3D:Mul(In2.Scale3D, Vec3Tmp2)

            -- 赋值
            Out.Translation:Reset(Vec3Tmp3)
            Out.Rotation:Reset(QuatTmp1)
            Out.Scale3D:Reset(Vec3Tmp2)
        end,

        Inverse = function(In, Out)
            if (In.Type ~= "Transform") or (Out.Type ~= "Transform") then
                print("Transform Mul Failed, Invalid Parameter !")
                return
            end

            -- 计算缩放
            Vec3Tmp1:Reset(In.Scale3D)
            if (MAbs(Vec3Tmp1.X) < 1e-8) then
                Vec3Tmp1.X = 0.0
            else
                Vec3Tmp1.X = 1.0 / Vec3Tmp1.X
            end
            if (MAbs(Vec3Tmp1.Y) < 1e-8) then
                Vec3Tmp1.Y = 0.0
            else
                Vec3Tmp1.Y = 1.0 / Vec3Tmp1.Y
            end
            if (MAbs(Vec3Tmp1.Z) < 1e-8) then
                Vec3Tmp1.Z = 0.0
            else
                Vec3Tmp1.Z = 1.0 / Vec3Tmp1.Z
            end

            --计算朝向
            local Rotation = In.Rotation
            QuatTmp1.X = Rotation.X * -1.0
            QuatTmp1.Y = Rotation.Y * -1.0
            QuatTmp1.Z = Rotation.Z * -1.0
            QuatTmp1.W = Rotation.W

            -- 计算坐标
            Vec3Tmp1:Mul(In.Translation, Vec3Tmp2)
            QuatTmp1:RotateVector(Vec3Tmp2, Vec3Tmp2)
            Vec3Tmp2:Mul(-1.0)

            -- 赋值
            Out.Translation:Reset(Vec3Tmp2)
            Out.Rotation:Reset(QuatTmp1)
            Out.Scale3D:Reset(Vec3Tmp1)
        end,

        TransformPosition = function(In, V, Out)
            if (In.Type ~= "Transform") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Transform TransformPosition Failed, Invalid Parameter !")
                return
            end

            In.Scale3D:Mul(V, Out)
            In.Rotation:RotateVector(Out, Out)
            In.Translation:Add(Out, Out)
        end,

        TransformPositionNoScale = function(In, V, Out)
            if (In.Type ~= "Transform") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Transform TransformPositionNoScale Failed, Invalid Parameter !")
                return
            end

            In.Rotation:RotateVector(V, Out)
            In.Translation:Add(Out, Out)
        end,

        TransformVector = function(In, V, Out)
            if (In.Type ~= "Transform") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Transform TransformVector Failed, Invalid Parameter !")
                return
            end

            In.Scale3D:Mul(V, Out)
            In.Rotation:RotateVector(Out, Out)
        end,

        TransformVectorNoScale = function(In, V, Out)
            if (In.Type ~= "Transform") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Transform TransformVectorNoScale Failed, Invalid Parameter !")
                return
            end

            In.Rotation:RotateVector(V, Out)
        end,

        InverseTransformPosition = function(In, V, Out)
            if (In.Type ~= "Transform") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Transform InverseTransformPosition Failed, Invalid Parameter !")
                return
            end

            V:Sub(In.Translation, Out)
            In.Rotation:UnrotateVector(Out, Out)

            local Scale3D = In.Scale3D
            if (MAbs(Scale3D.X) < 1e-8) then
                Out.X = 0.0
            else
                Out.X = Out.X * (1.0 / Scale3D.X)
            end
            if (MAbs(Scale3D.Y) < 1e-8) then
                Out.Y = 0.0
            else
                Out.Y = Out.Y * (1.0 / Scale3D.Y)
            end
            if (MAbs(Scale3D.Z) < 1e-8) then
                Out.Z = 0.0
            else
                Out.Z = Out.Z * (1.0 / Scale3D.Y)
            end
        end,

        InverseTransformPositionNoScale = function(In, V, Out)
            if (In.Type ~= "Transform") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Transform InverseTransformPositionNoScale Failed, Invalid Parameter !")
                return
            end

            V:Sub(In.Translation, Out)
            In.Rotation:UnrotateVector(Out, Out)
        end,

        InverseTransformVector = function(In, V, Out)
            if (In.Type ~= "Transform") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Transform InverseTransformVector Failed, Invalid Parameter !")
                return
            end

            In.Rotation:UnrotateVector(V, Out)

            local Scale3D = In.Scale3D
            if (MAbs(Scale3D.X) < 1e-8) then
                Out.X = 0.0
            else
                Out.X = Out.X * (1.0 / Scale3D.X)
            end
            if (MAbs(Scale3D.Y) < 1e-8) then
                Out.Y = 0.0
            else
                Out.Y = Out.Y * (1.0 / Scale3D.Y)
            end
            if (MAbs(Scale3D.Z) < 1e-8) then
                Out.Z = 0.0
            else
                Out.Z = Out.Z * (1.0 / Scale3D.Y)
            end
        end,

        InverseTransformVectorNoScale = function(In, V, Out)
            if (In.Type ~= "Transform") or (V.Type ~= "Vec3") or (Out.Type ~= "Vec3") then
                print("Transform InverseTransformVectorNoScale Failed, Invalid Parameter !")
                return
            end

            In.Rotation:UnrotateVector(V, Out)
        end,

        TransformRotation = function(In, Q, Out)
            if (In.Type ~= "Transform") or (Q.Type ~= "Quat") or (Out.Type ~= "Quat") then
                print("Transform TransformRotation Failed, Invalid Parameter !")
                return
            end

            In.Rotation:Mul(Q, Out)
        end,

        InverseTransformRotation = function(In, Q, Out)
            if (In.Type ~= "Transform") or (Q.Type ~= "Quat") or (Out.Type ~= "Quat") then
                print("Transform TransformRotation Failed, Invalid Parameter !")
                return
            end

            local Rotation = In.Rotation
            QuatTmp1.X = Rotation.X * -1.0
            QuatTmp1.Y = Rotation.Y * -1.0
            QuatTmp1.Z = Rotation.Z * -1.0
            QuatTmp1.W = Rotation.W

            QuatTmp1:Mul(Q, Out)
        end
    }
}
setmetatable(M3D.Transform, M3D.Transform)
local TransformTmp1 = M3D.Transform()
local TransformTmp2 = M3D.Transform()
local TransformTmp3 = M3D.Transform()
-- endregion Transform






-- region Function
-- LuaTable转FVector2D
function M3D.ToFVector2D(InTable, InFVector2D)
    if (InFVector2D ~= nil) then
        InFVector2D.X = InTable.X or 0.0
        InFVector2D.Y = InTable.Y or 0.0

        return InFVector2D
    end

    return FVector2D(InTable.X, InTable.Y)
end

-- LuaTable转Vec2
function M3D.ToVec2(InTable, InVec2)
    if (InVec2 ~= nil) and (InVec2.Type == "Vec2") then
        InVec2.X = InTable.X or 0.0
        InVec2.Y = InTable.Y or 0.0

        return InVec2
    end

    return M3D.Vec2(InTable.X, InTable.Y)
end

-- LuaTable转FVector
function M3D.ToFVector(InTable, InFVector)
    if (InFVector ~= nil) then
        InFVector.X = InTable.X or 0.0
        InFVector.Y = InTable.Y or 0.0
        InFVector.Z = InTable.Z or 0.0

        return InFVector
    end

    return FVector(InTable.X, InTable.Y, InTable.Z)
end

-- LuaTable转Vec3
function M3D.ToVec3(InTable, InVec3)
    if (InVec3 ~= nil) and (InVec3.Type == "Vec3") then
        InVec3.X = InTable.X or 0.0
        InVec3.Y = InTable.Y or 0.0
        InVec3.Z = InTable.Z or 0.0

        return InVec3
    end

    return M3D.Vec3(InTable.X, InTable.Y, InTable.Z)
end

function M3D.ArrToVec3(InTable, InVec3)
    if (InVec3 ~= nil) and (InVec3.Type == "Vec3") then
        InVec3.X = InTable[1] or 0.0
        InVec3.Y = InTable[2] or 0.0
        InVec3.Z = InTable[3] or 0.0

        return InVec3
    end

    return M3D.Vec3(InTable[1], InTable[2], InTable[3])
end

-- LuaTable转FVector4
function M3D.ToFVector4(InTable, InFVector4)
    if (InFVector4 ~= nil) then
        InFVector4.X = InTable.X or 0.0
        InFVector4.Y = InTable.Y or 0.0
        InFVector4.Z = InTable.Z or 0.0
        InFVector4.W = InTable.W or 0.0

        return InFVector4
    end

    return FVector4(InTable.X, InTable.Y, InTable.Z, InTable.W)
end

-- LuaTable转FLinearColor
function M3D.ToFLinearColor(InTable, InFLinearColor)
    local Result = InFLinearColor
    if (Result == nil) then
        Result = FLinearColor()
    end

    Result.R = InTable.X or InTable.R or 0.0
    Result.G = InTable.Y or InTable.G or 0.0
    Result.B = InTable.Z or InTable.B or 0.0
    Result.A = InTable.W or InTable.A or 0.0

    return Result
end

-- LuaTable转FQuat
function M3D.ToFQuat(InTable, InFQuat)
    if (InFQuat ~= nil) then
        InFQuat.X = InTable.X or 0.0
        InFQuat.Y = InTable.Y or 0.0
        InFQuat.Z = InTable.Z or 0.0
        InFQuat.W = InTable.W or 1.0

        return InFQuat
    end

    return FQuat(InTable.X, InTable.Y, InTable.Z, InTable.W)
end

-- LuaTable转Quat
function M3D.ToQuat(InTable, InQuat)
    if (InQuat ~= nil) and (InQuat.Type == "Quat") then
        InQuat.X = InTable.X or 0.0
        InQuat.Y = InTable.Y or 0.0
        InQuat.Z = InTable.Z or 0.0
        InQuat.W = InTable.W or 1.0

        return InQuat
    end

    return M3D.Quat(InTable.X, InTable.Y, InTable.Z, InTable.W)
end

function M3D.ArrToQuat(InTable, InQuat)
    if (InQuat ~= nil) and (InQuat.Type == "Quat") then
        InQuat.X = InTable[1] or 0.0
        InQuat.Y = InTable[2] or 0.0
        InQuat.Z = InTable[3] or 0.0
        InQuat.W = InTable[4] or 1.0

        return InQuat
    end

    return M3D.Quat(InTable[1], InTable[2], InTable[3], InTable[4])
end

-- FRotator转Quat
function M3D.FRotToQuat(InFRot, InQuat)
    local HalfDToR = 0.008726646

    local RadP = (InFRot.Pitch or 0.0) * HalfDToR
    local SinP = MaintainAccuracy(MSin(RadP))
    local CosP = MaintainAccuracy(MCos(RadP))

    local RadY = (InFRot.Yaw or 0.0) * HalfDToR
    local SinY = MaintainAccuracy(MSin(RadY))
    local CosY = MaintainAccuracy(MCos(RadY))

    local RadR = (InFRot.Roll or 0.0) * HalfDToR
    local SinR = MaintainAccuracy(MSin(RadR))
    local CosR = MaintainAccuracy(MCos(RadR))

    local X = CosR * SinP * SinY - SinR * CosP * CosY
    local Y = -CosR * SinP * CosY - SinR * CosP * SinY
    local Z = CosR * CosP * SinY - SinR * SinP * CosY
    local W = CosR * CosP * CosY + SinR * SinP * SinY

    if (InQuat ~= nil) and (InQuat.Type == "Quat") then
        InQuat.X = X
        InQuat.Y = Y
        InQuat.Z = Z
        InQuat.W = W

        return InQuat
    end

    return M3D.Quat(X, Y, Z, W)
end

-- LuaTable转FRotator
function M3D.ToFRotator(InTable, InFRotator)
    if (InFRotator ~= nil) then
        InFRotator.Roll = InTable.Roll or 0.0
        InFRotator.Pitch = InTable.Pitch or 0.0
        InFRotator.Yaw = InTable.Yaw or 0.0

        return InFRotator
    end

    return FRotator(InTable.Pitch, InTable.Yaw, InTable.Roll)
end

-- LuaTable转Rotator
function M3D.ToRotator(InTable, InRotator)
    if (InRotator ~= nil) and (InRotator.Type == "Rotator") then
        InRotator.Roll = InTable.Roll or 0.0
        InRotator.Pitch = InTable.Pitch or 0.0
        InRotator.Yaw = InTable.Yaw or 0.0

        return InRotator
    end

    return M3D.InRotator(InTable.Roll, InTable.Pitch, InTable.Yaw)
end

-- LuaTable转FTransform
function M3D.ToFTransform(InTable, InFTransform)
    if (InFTransform ~= nil) and (InFTransform.__name == "FTransform") then
        M3D.ToFQuat(InTable.Rotation, TransRot)
        M3D.ToFVector(InTable.Translation, TransLoc)
        M3D.ToFVector(InTable.Scale3D, TransScale)

        InFTransform:SetRotation(TransRot)
        InFTransform:SetLocation(TransLoc)
        InFTransform:SetScale3D(TransScale)

        return InFTransform
    end

    return FTransform(M3D.ToFQuat(InTable.Rotation), M3D.ToFVector(InTable.Translation), M3D.ToFVector(InTable.Scale3D))
end

-- LuaTable转Transform
function M3D.ToTransform(InTable, InTransform)
    local NewTransform = InTransform
    if (NewTransform == nil) or (NewTransform.Type ~= "Transform") then
        NewTransform = M3D.Transform()
    end

    if (InTable.__name == "FTransform") then
        M3D.ToVec3(InTable:GetLocation(), NewTransform.Translation)
        M3D.ToQuat(InTable:GetRotation(), NewTransform.Rotation)
        M3D.ToVec3(InTable:GetScale3D(), NewTransform.Scale3D)
    else
        M3D.ToVec3(InTable.Translation, NewTransform.Translation)
        M3D.ToQuat(InTable.Rotation, NewTransform.Rotation)
        M3D.ToVec3(InTable.Scale3D, NewTransform.Scale3D)
    end

    return NewTransform
end

-- 使用FVector和FRotator组装Transform
function M3D.AssembleTransform(InFL, InFR, InFS, InTransform)
    local NewTransform = InTransform
    if (NewTransform == nil) or (NewTransform.Type ~= "Transform") then
        NewTransform = M3D.Transform()
    end

    if (InFL ~= nil) then
        M3D.ToVec3(InFL, NewTransform.Translation)
    else
        NewTransform.Translation:Reset()
    end

    if (InFR ~= nil) then
        M3D.ToQuat(InFR, NewTransform.Rotation)
    else
        NewTransform.Rotation:Reset()
    end

    if (InFS ~= nil) then
        M3D.ToVec3(InFS, NewTransform.Scale3D)
    else
        NewTransform.Scale3D:Reset(1.0, 1.0, 1.0)
    end

    return NewTransform
end

function M3D.ArrAssembleTransform(InFL, InFR, InFS, InTransform)
    local NewTransform = InTransform
    if (NewTransform == nil) or (NewTransform.Type ~= "Transform") then
        NewTransform = M3D.Transform()
    end

    if (InFL ~= nil and table.count(InFL) >= 3) then
        M3D.ArrToVec3(InFL, NewTransform.Translation)
    else
        NewTransform.Translation:Reset()
    end

    if (InFR ~= nil and table.count(InFR) >= 3) then
        M3D.ToQuat(InFR, NewTransform.Rotation)
    else
        NewTransform.Rotation:Reset()
    end

    if (InFS ~= nil and table.count(InFS) >= 3) then
        M3D.ArrToVec3(InFS, NewTransform.Scale3D)
    else
        NewTransform.Scale3D:Reset(1.0, 1.0, 1.0)
    end

    return NewTransform
end

function M3D.ConvertToTransform(InFL, InFR, InFS, InTransform)
    local NewTransform = InTransform
    if (NewTransform == nil) or (NewTransform.Type ~= "Transform") then
        NewTransform = M3D.Transform()
    end

    if (InFL ~= nil and table.count(InFL) >= 3) then
        local Loc = {}
        if  (InFL.Type ~= "Vec3") then
            if InFL.X == nil then
                Loc.X = InFL[1]
                Loc.Y = InFL[2]
                Loc.Z = InFL[3]
            else
                Loc.X = InFL.X
                Loc.Y = InFL.Y
                Loc.Z = InFL.Z
            end
        else
            Loc = InFL
        end
        M3D.ToVec3(Loc, NewTransform.Translation)
    else
        NewTransform.Translation:Reset()
    end

    if (InFR ~= nil and table.count(InFR) >= 3) then
        local Rot = {}
        if  (InFR.Type ~= "Rotator") then
            if InFR.X == nil then
                Rot.Roll = InFR[1]
                Rot.Pitch = InFR[2]
                Rot.Yaw = InFR[3]
            else
                Rot.Roll = InFR.X
                Rot.Pitch = InFR.Y
                Rot.Yaw = InFR.Z
            end
        else
            Rot = InFR
        end
        local Quat = M3D.FRotToQuat(Rot)
        M3D.ToQuat(Quat, NewTransform.Rotation)
    else
        NewTransform.Rotation:Reset()
    end

    if (InFS ~= nil and table.count(InFS) >= 3) then
        local Scale = {}
        if  (InFS.Type ~= "Vec3") then
            if InFS.X == nil then
                Scale.X = InFS[1]
                Scale.Y = InFS[2]
                Scale.Z = InFS[3]
            else
                Scale.X = InFS.X
                Scale.Y = InFS.Y
                Scale.Z = InFS.Z
            end
        else
            Scale = InFS
        end
        M3D.ToVec3(Scale, NewTransform.Scale3D)
    else
        NewTransform.Scale3D:Reset(1.0, 1.0, 1.0)
    end

    return NewTransform
end
-- 判断是否是零向量
function M3D.IsZeroVec3(InVec3)
    if (InVec3.X == nil) or (math.abs(InVec3.X) > 0.0001) then
        return false
    end

    if (InVec3.Y == nil) or (math.abs(InVec3.Y) > 0.0001) then
        return false
    end

    if (InVec3.Z == nil) or (math.abs(InVec3.Z) > 0.0001) then
        return false
    end

    return true
end

-- 判断是否是零旋转
function M3D.IsZeroRotator(InRotator)
    if (InRotator.Roll == nil) or (math.abs(InRotator.Roll) > 0.0001) then
        return false
    end

    if (InRotator.Pitch == nil) or (math.abs(InRotator.Pitch) > 0.0001) then
        return false
    end

    if (InRotator.Yaw == nil) or (math.abs(InRotator.Yaw) > 0.0001) then
        return false
    end

    return true
end

-- 判断是否是单元四元数
function M3D.IsIdentityQuat(InQuat)
    if (InQuat.X == nil) or (math.abs(InQuat.X) > 0.0001) then
        return false
    end

    if (InQuat.Y == nil) or (math.abs(InQuat.Y) > 0.0001) then
        return false
    end

    if (InQuat.Z == nil) or (math.abs(InQuat.Z) > 0.0001) then
        return false
    end

    if (InQuat.W == nil) or (math.abs(InQuat.W) - 1.0 > 0.0001) then
        return false
    end

    return true
end

-- 判断是否是单元变换
function M3D.IsIdentityTransform(InTransform)
    if (InTransform == nil) then
        return false
    end

    local Comp = InTransform.Translation
    if (Comp == nil) or (M3D.IsZeroVec3(Comp) == false) then
        return false
    end

    Comp = InTransform.Rotation
    if (Comp == nil) or (M3D.IsIdentityQuat(Comp) == false) then
        return false
    end

    Comp = InTransform.Scale3D
    if (Comp == nil) or (Comp.X == nil) or (math.abs(Comp.X - 1.0) > 1e-4) or (Comp.Y == nil) or (math.abs(Comp.Y - 1.0) > 1e-4) or (Comp.Z == nil) or (math.abs(Comp.Z - 1.0) > 1e-4) then
        return false
    end

    return true
end

-- 填充3个0
function M3D.Fill3()
    return 0.0, 0.0, 0.0
end

-- 填充4个0
function M3D.Fill4()
    return 0.0, 0.0, 0.0, 0.0
end

-- 填充10个0
function M3D.Fill10()
    return 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
end

-- 根据Target得到转向的yaw
function M3D.GetTargetYawByVector(location, target)
    return M3D.atan2(target.Y - location.Y, target.X - location.X) * 180.0 / math.pi
end

function M3D.atan2(y, x)
    local PI = math.pi
    if x > 0 then
        return math.atan(y/x)
    elseif y >= 0 and x < 0 then
        return math.atan(y/x) + PI
    elseif y < 0 and x < 0 then
        return math.atan(y/x) - PI
    elseif y > 0 and x == 0 then
        return PI / 2
    elseif y < 0 and x == 0 then
        return -PI / 2
    else
        -- x == 0 and y == 0
        -- atan2 is undefined for these inputs
        return nil
    end
end

function M3D.GetWorldTransform(InTargetLoc, InTargetRot, InTransform)
    local PlayerTransform = M3D.AssembleTransform(InTargetLoc, M3D.FRotToQuat(InTargetRot))
    local FinalTransform = M3D.Transform()
    InTransform:Mul(PlayerTransform, FinalTransform)
    return FinalTransform
end

function M3D.GetDistance3D(PosA, PosB)
    local disX = PosA.X - PosB.X
    local disY = PosA.Y - PosB.Y
    local disZ = PosA.Z - PosB.Z
    return MSqrt(disX*disX + disY*disY + disZ*disZ)
end

function M3D.GetDistance(PosA, PosB)
    local disX = PosA.X - PosB.X
    local disY = PosA.Y - PosB.Y
    return MSqrt(disX*disX + disY*disY)
end

-- 修正转向角度(-180, 180)
function M3D.UnwindDegrees(yaw)
	while yaw > 180.0 do
		yaw = yaw - 360.0
	end

	while yaw < -180.0 do
		yaw = yaw + 360.0
	end

	return yaw
end

-- 根据朝向计算Rotation
function M3D.GetRotationByDir(Direction)
    if (Direction == nil) then
        return M3D.Quat(0.0, 0.0, 0.0, 1.0)
    end
    if (Direction.X == 0.0) and (Direction.Y == 0.0) then
        return M3D.Quat(0.0, 0.0, 0.0, 1.0)
    end
    local yaw = M3D.atan2(Direction.Y, Direction.X) * 180.0 / math.pi 
    local pitch = M3D.atan2(Direction.Z, math.sqrt(Direction.X * Direction.X + Direction.Y * Direction.Y)) * 180.0 / math.pi
    local roll = 0.0
    local Rot = M3D.Rotator(roll, pitch, yaw)
    local outQuat = M3D.Quat()
    M3D.FRotToQuat(Rot, outQuat)
    return outQuat
end

-- 四元数取逆
function M3D.InverseQuaternion(q)
    local OutQuat = M3D.Quat()
    local normSquared = q.W*q.W + q.X*q.X + q.Y*q.Y + q.Z*q.Z
    if normSquared == 0.0 then
        return OutQuat
    end
    OutQuat:Pack(-q.X/normSquared, -q.Y/normSquared, -q.Z/normSquared, q.W/normSquared)
    return OutQuat
end

-- 计算两点之间距离z时的坐标
function M3D.GetPointByDistanceZ(Start, End, Z, MaxDistance)
    if (Start.X-End.X)*(Start.X-End.X) + (Start.Y-End.Y)*(Start.Y-End.Y) + (Start.Z-End.Z)*(Start.Z-End.Z) < 0.0001 then
        return End
    end
    local Direction = M3D.Vec3()
    End:Sub(Start, Direction)
    local len = Direction:Size()
    len = len - Z
    if len > MaxDistance then
        len = MaxDistance
    end
    Direction:Normalize()
    local NewEnd = M3D.Vec3()
    Direction:Mul(len, Direction)
    Start:Add(Direction, NewEnd)
    return NewEnd
end

function M3D.RotateVectorByYaw(vector3D, yaw)
	local radYaw = math.rad(yaw) -- Convert yaw to radians
	local cosYaw = math.cos(radYaw)
	local sinYaw = math.sin(radYaw)

	local x = vector3D.X * cosYaw - vector3D.Y * sinYaw
	local y = vector3D.X * sinYaw + vector3D.Y * cosYaw

	vector3D.X = x
	vector3D.Y = y
end
-- endregion Function
