inherited SampleWebModule: TSampleWebModule
  Actions = <
    item
      Default = True
      Name = 'WebActionItem1'
      OnAction = OlfTDSWebModule_404PageNotFoundAction
    end
    item
      MethodType = mtPost
      Name = 'WebActionItem2'
      PathInfo = '/login'
      OnAction = APILogin
    end
    item
      MethodType = mtPost
      Name = 'WebActionItem3'
      PathInfo = '/srv2loc'
      OnAction = APISrv2Loc
    end
    item
      MethodType = mtPost
      Name = 'WebActionItem4'
      PathInfo = '/loc2srv'
      OnAction = APILoc2Srv
    end
    item
      MethodType = mtPost
      Name = 'WebActionItem5'
      PathInfo = '/logout'
      OnAction = APILogout
    end>
  object FDPhysSQLiteDriverLink2: TFDPhysSQLiteDriverLink
    Left = 192
    Top = 96
  end
end
