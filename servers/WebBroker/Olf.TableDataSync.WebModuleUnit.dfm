object OlfTDSWebModule: TOlfTDSWebModule
  Actions = <
    item
      Default = True
      Name = '_404PageNotFound'
      OnAction = OlfTDSWebModule_404PageNotFoundAction
    end
    item
      MethodType = mtPost
      Name = 'SessionOpen'
      PathInfo = '/login'
      OnAction = APILogin
    end
    item
      MethodType = mtPost
      Name = 'SyncServerToClient'
      PathInfo = '/srv2loc'
      OnAction = APISrv2Loc
    end
    item
      MethodType = mtPost
      Name = 'SyncClientToServer'
      PathInfo = '/loc2srv'
      OnAction = APILoc2Srv
    end
    item
      MethodType = mtPost
      Name = 'SessionClose'
      PathInfo = '/logout'
      OnAction = APILogout
    end>
  Height = 230
  Width = 415
end
