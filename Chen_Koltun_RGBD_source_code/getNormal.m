%get the normal map from depth map
function  N=getNormal(Z)
	V=getVectors(size(Z,1),size(Z,2));
	V=V.*Z(:,:,[1 1 1]);
	[nx ny nz]=surfnorm(V(:,:,1),V(:,:,2),V(:,:,3));
	N=cat(3,nx,ny,nz);
end
