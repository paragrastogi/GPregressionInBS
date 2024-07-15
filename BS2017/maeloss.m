function [mae, icr] = maeloss(ypred, ytest)

% A function to compute Mean Absolute Error
% Written by Parag Rastogi, adapted from Emtiyaz Khan (EPFL)
% October 24, 2016

  % Mean Absolute Error loss
  err = ypred - ytest;
  idx = (~isnan(ytest));
  mae = nanmean(abs(err(idx)));
  
  % incorrect classification rate
  icr = 1 - sum(err==0)/sum(idx);
        
end