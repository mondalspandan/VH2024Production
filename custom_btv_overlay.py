def PrepBTVCustomNanoAOD_MC_LatentFeatures(
    process, CLS=True, MLP=True, InputEncoder=True
):
    from PhysicsTools.NanoAOD.custom_btv_cff import BTVCustomNanoAOD_LatentFeatures

    return BTVCustomNanoAOD_LatentFeatures(
        process, CLS=CLS, MLP=MLP, InputEncoder=InputEncoder
    )
