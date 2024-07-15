function [mae_coll, rmse_coll, hyp_coll, ypred_coll] = ...
    LoadResults(ser, seeds, lo, pathMATfolder)

runserr = load(fullfile(pathMATfolder, ...
    sprintf('errs_%s_%d_%d.mat', ser, 1, lo)));
runsy = load(fullfile(pathMATfolder, ...
    sprintf('ystore_%s_%d_%d.mat', ser, 1, lo)));


mae_coll = nan([size(runserr.mae),length(seeds)]);
rmse_coll = nan([size(runserr.rmse),length(seeds)]);
hyp_coll = nan([size(runserr.hyp),length(seeds)]);
ypred_coll = nan([size(runsy.ypred),length(seeds)]);

cntr = 1;

for v = seeds
    try
        runserr = load(fullfile(pathMATfolder, ...
            sprintf('errs_%s_%d_%d.mat',ser, v, lo)));
        mae_coll(:,:,cntr) = runserr.mae;
        rmse_coll(:,:,cntr) = runserr.rmse;
        hyp_coll(:,:,:,cntr) = runserr.hyp;
        
        runsy = load(fullfile(pathMATfolder, ...
            sprintf('ystore_%s_%d_%d.mat',ser, v, lo)));
        ypred_coll(:,:,:,cntr) = runsy.ypred;
    
        cntr = cntr + 1;
    catch err
        fprintf('%s\r\n', err.message)
    end
    
end

% clear runserr runserr_un runsy runsy_un

end