function out=weightedMedian(D,W)
	if numel(D) ~= numel(W)
		error('weightedMedian:wrongMatrixDimension', 'The dimensions of the input-matrices must match.');
	end
	A=[D(:) W(:)/sum(W(:))];
	ASort=sortrows(A,1);
	sumVec=cumsum(ASort(:,2));
	out=ASort(min(find(sumVec>=0.5)),1);
end